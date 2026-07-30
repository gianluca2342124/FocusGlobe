-- ============================================================================
-- FocusGlobe Online — ACTIVE_FLIGHTS SCHEMA COMPATIBILITY
--
-- WHY THIS EXISTS
--   Production raised, at runtime:
--       column "sound_id" of relation "active_flights" does not exist
--   so publish_flight_session failed, no canonical session was ever confirmed,
--   and Invite Friends stayed on "Your flight is still connecting".
--
--   Root cause: migration 20260718090000_focusglobe_pilot_metadata.sql was never
--   applied to this database. It is the ONLY place that adds
--   active_flights.sound_id — and it is also the only place that creates the
--   applause_events table and the send_applause() RPC, both of which the shipped
--   app calls. So sound_id was NOT the only gap.
--
--   The two newest migrations (…120000 per-pilot pause, …160000 private-room
--   pause) applied cleanly despite the missing column because PostgreSQL does not
--   resolve table references inside a plpgsql body at CREATE time — only on first
--   execution. That is precisely why this surfaced as a runtime error rather than
--   a failed deployment.
--
-- WHAT THIS DOES
--   Re-applies, idempotently, exactly the parts of 20260718090000 that the
--   currently shipped client depends on. It does NOT modify either already
--   deployed migration, and it is safe to run whether or not 20260718090000 was
--   applied in whole or in part:
--     • add column if not exists / create table if not exists
--     • create or replace function
--     • drop policy if exists before create policy
--     • publication membership guarded by a catalog check
--
--   No table is recreated, no data is rewritten, no RLS is relaxed, no index or
--   constraint is dropped.
--
-- COLUMN AUDIT (every column the shipped RPC contract touches)
--   Present since the base table 20260716090000:
--     user_id, sky_id, balloon_skin_id, session_kind, focus_category,
--     started_at, expected_end_at, paused_at, status, last_heartbeat_at,
--     expires_at
--   Added by 20260717150000: client_session_id
--   Added by 20260730120000: paused_remaining_seconds
--   Added by 20260730160000: room_id
--   MISSING → added here: sound_id
--
--   Deliberately NOT columns on this table, and correctly so:
--     is_paused   — derived as (paused_at is not null); returned as a computed
--                   jsonb field, never stored.
--     is_active / ended_at
--                 — this table models liveness with status ('active'/'ended')
--                   plus expires_at; there is no separate boolean or end stamp.
--     skin_id / category
--                 — exist under their canonical names balloon_skin_id and
--                   focus_category (the Swift CodingKeys already map to these).
--     alias / country / discoverability
--                 — live on public.profiles and are joined client-side; the
--                   presence row deliberately stores no profile data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The missing presentation column.
--
--    sound_id is the journey-sound id from the app's fixed catalog (validated on
--    display). Nullable with no default: an existing row simply has no shared
--    sound until its next publish, and nothing reads it as required.
-- ----------------------------------------------------------------------------
alter table public.active_flights
  add column if not exists sound_id text;

-- ----------------------------------------------------------------------------
-- 2. Remove any is_pro column left by a partially-run earlier revision.
--
--    PRO is intentionally NOT part of public presence (there is no trusted
--    server-side entitlement source, so a self-asserted flag would be
--    spoofable). This matters beyond tidiness: publish_flight_session does not
--    list is_pro in its INSERT, so a leftover NOT NULL is_pro without a default
--    would make every publish fail. No-op when the column was never created.
-- ----------------------------------------------------------------------------
alter table public.active_flights
  drop column if exists is_pro;

-- ----------------------------------------------------------------------------
-- 3. applause_events — also missing, and also required by the shipped client
--    (PublicFlightService reads this table and RealtimeService subscribes to it).
--
--    Writes happen ONLY through send_applause() (SECURITY DEFINER); clients get
--    no INSERT/UPDATE/DELETE policy. The single SELECT policy (recipient only)
--    is also what makes Realtime deliver an event exclusively to its recipient.
-- ----------------------------------------------------------------------------
create table if not exists public.applause_events (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  sender_alias text not null,
  created_at   timestamptz not null default clock_timestamp()
);
create index if not exists applause_events_recipient_idx
  on public.applause_events (recipient_id, created_at desc);
create index if not exists applause_events_pair_idx
  on public.applause_events (sender_id, recipient_id, created_at desc);

alter table public.applause_events enable row level security;

-- A user may READ ONLY applause addressed to them. No write policy exists, so
-- direct client INSERT/UPDATE/DELETE is denied — only the definer RPC writes.
drop policy if exists applause_events_select_own on public.applause_events;
create policy applause_events_select_own on public.applause_events
  for select to authenticated
  using (recipient_id = (select auth.uid()));

-- Realtime delivery (idempotent add to the standard Supabase publication).
--
-- Wrapped so a permissions failure cannot abort this migration. Altering a
-- publication needs elevated rights, and the CRITICAL part of this file is the
-- sound_id column — that must land even if realtime cannot be reconfigured here.
-- Applause would then still work by polling; only its instant push is lost, and
-- the ALTER can be run separately by an owner.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'applause_events'
  ) then
    alter publication supabase_realtime add table public.applause_events;
  end if;
exception
  when insufficient_privilege or undefined_object then
    raise notice 'applause_events not added to supabase_realtime (%). Add it manually if push applause is wanted.', sqlerrm;
end $$;

-- ----------------------------------------------------------------------------
-- 4. send_applause — the ONLY way to create an applause event. Enforces every
--    invariant server-side; the sender's alias is fetched here, never trusted
--    from the client. Returns {status:'sent'} or raises a precise token the app
--    maps to friendly UI. No rewards. Opportunistic cleanup keeps it tiny.
--
--    Reproduced verbatim from 20260718090000 so the two definitions cannot
--    diverge. Note it already works for the room-kind sessions introduced by
--    20260730160000: the "sender is live" and "recipient is visible" checks each
--    have a private-room branch keyed on room_members, so a pilot whose
--    session_kind is now 'room' still passes through the membership path.
-- ----------------------------------------------------------------------------
create or replace function public.send_applause(p_recipient uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_alias text;
  v_sender_live boolean;
  v_visible boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_recipient is null then raise exception 'invalid_recipient'; end if;
  if p_recipient = uid then raise exception 'applause_self'; end if;

  -- Serialise concurrent requests for THIS ordered pair so two simultaneous
  -- taps cannot both pass the cooldown check (advisory xact lock; auto-released
  -- at commit). hashtext → int4, so the two-key advisory lock fits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(uid::text), pg_catalog.hashtext(p_recipient::text));

  -- Blocked pairs may not applaud each other.
  if private.is_blocked_pair(uid, p_recipient) then raise exception 'blocked'; end if;

  -- The SENDER must be in a live online flight: a fresh public Global presence
  -- OR a joined member of an active private room.
  select
       exists (select 1 from public.active_flights
                where user_id = uid and status = 'active' and session_kind = 'public'
                  and last_heartbeat_at > now() - interval '150 seconds')
    or exists (select 1 from public.room_members m
                 join public.focus_rooms r on r.id = m.room_id
                where m.user_id = uid and m.status = 'joined' and r.status = 'active')
    into v_sender_live;
  if not v_sender_live then raise exception 'not_flying'; end if;

  -- The RECIPIENT must be a REAL, visible pilot in the SENDER's current flight:
  --   • Global: both are fresh public presences in the SAME Sky, OR
  --   • Private: both are currently-joined members of the SAME active room and
  --     the recipient's membership heartbeat is fresh.
  -- This is exactly the set the sender can actually see — nobody can applaud an
  -- arbitrary UUID outside their flight.
  select
       exists (
         select 1 from public.active_flights me
           join public.active_flights them on them.sky_id = me.sky_id
          where me.user_id = uid and me.status = 'active' and me.session_kind = 'public'
            and me.last_heartbeat_at > now() - interval '150 seconds'
            and them.user_id = p_recipient and them.status = 'active'
            and them.session_kind = 'public'
            and them.last_heartbeat_at > now() - interval '150 seconds')
    or exists (
         select 1 from public.room_members me
           join public.room_members them on them.room_id = me.room_id
           join public.focus_rooms r on r.id = me.room_id
          where me.user_id = uid and me.status = 'joined'
            and them.user_id = p_recipient and them.status = 'joined'
            and r.status = 'active'
            and them.last_heartbeat_at > now() - interval '150 seconds')
    into v_visible;
  if not v_visible then raise exception 'recipient_not_flying'; end if;

  -- Server-side cooldown: one applause per ordered pair per 45 s (race-safe
  -- under the advisory lock held above).
  if exists (
    select 1 from public.applause_events
     where sender_id = uid and recipient_id = p_recipient
       and created_at > now() - interval '45 seconds'
  ) then
    raise exception 'applause_cooldown';
  end if;

  -- The alias is the sender's REAL public alias, fetched server-side.
  select coalesce(nullif(public_alias, ''), 'A pilot') into v_alias
    from public.profiles where id = uid;

  insert into public.applause_events (sender_id, recipient_id, sender_alias)
  values (uid, p_recipient, v_alias);

  -- Ephemeral: trim this recipient's rows older than 5 minutes (nobody reads
  -- applause older than a few seconds).
  delete from public.applause_events
   where recipient_id = p_recipient and created_at < now() - interval '5 minutes';

  return jsonb_build_object('status', 'sent');
end $$;

revoke execute on function public.send_applause(uuid) from public, anon;
grant  execute on function public.send_applause(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Re-assert the grants for the two session RPCs the client now calls, so a
--    database that received …160000 before this file still ends up with exactly
--    the intended execution rights. Idempotent.
-- ----------------------------------------------------------------------------
revoke execute on function public.publish_flight_session(text, text, text, text, integer, boolean, boolean, text, uuid)
  from public, anon;
grant  execute on function public.publish_flight_session(text, text, text, text, integer, boolean, boolean, text, uuid)
  to authenticated;
revoke execute on function public.bind_flight_session_to_room(text, uuid) from public, anon;
grant  execute on function public.bind_flight_session_to_room(text, uuid) to authenticated;
