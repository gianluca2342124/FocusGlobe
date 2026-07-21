-- ============================================================================
-- FocusGlobe Online — validated pilot display metadata + a SERVER-AUTHORITATIVE
-- applause channel.
--
-- PRO IS NOT PUBLISHED AS PILOT METADATA. FocusGlobe's entitlement authority is
-- RevenueCat / StoreKit on the device; Supabase holds no trusted server-side
-- entitlement record, so a self-asserted client PRO flag would be spoofable. The
-- badge is therefore omitted from public presence entirely — no is_pro column,
-- no is_pro parameter. Only a length-capped sound id rides the presence row, and
-- it is validated against the app's FIXED sound catalog on display (an unknown
-- id shows nothing, never raw text).
--
-- APPLAUSE IS SERVER-AUTHORIZED. auth.uid() is always the sender; the sender's
-- public alias is filled BY THE SERVER (never client-supplied); sender ≠
-- recipient; both must be co-present in the same live public Sky; blocked pairs
-- are refused; a 45-second per-ordered-pair cooldown is enforced under a
-- transaction advisory lock (race-safe). Delivery is RLS-scoped: a recipient can
-- read ONLY applause addressed to them, and Realtime honours that policy, so no
-- authenticated user can subscribe to anyone else's applause stream. No coins or
-- rewards are ever granted; events are ephemeral and self-cleaned.
--
-- Idempotent; safe after all prior migrations. Preserves the canonical
-- publish_global_flight timing and old-client compatibility (the new parameter
-- is defaulted). Preserves RLS; auth.uid() authority; pinned empty search_path;
-- fully-qualified objects; EXECUTE revoked from public + anon, granted only to
-- authenticated.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Pilot display metadata: a validated sound id ONLY (no trusted PRO source).
--    Any earlier is_pro column from a partially-run version of this file is
--    dropped, so no untrusted PRO value can linger.
-- ----------------------------------------------------------------------------
alter table public.active_flights drop column if exists is_pro;
alter table public.active_flights add column if not exists sound_id text;

-- Recreate the canonical publisher with ONE extra DEFAULTED parameter
-- (p_sound_id). Old clients still call with seven named params → the eighth
-- defaults, so there is exactly one resolvable publish_global_flight. Both the
-- original 7-arg and any 9-arg (is_pro) variant are dropped first.
drop function if exists public.publish_global_flight(text, text, text, text, integer, boolean, boolean);
drop function if exists public.publish_global_flight(text, text, text, text, integer, boolean, boolean, boolean, text);

create or replace function public.publish_global_flight(
    p_client_session_id text,
    p_sky_id            text,
    p_balloon_skin_id   text,
    p_focus_category    text,
    p_duration_seconds  integer,
    p_is_infinite       boolean,
    p_is_paused         boolean default false,
    p_sound_id          text    default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  existing public.active_flights;
  v_started timestamptz;
  v_end timestamptz;
  result public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  if p_sky_id is null or length(p_sky_id) = 0 then raise exception 'invalid_sky'; end if;
  perform private.ensure_profile(uid);

  select * into existing from public.active_flights where user_id = uid for update;

  if existing.user_id is not null
     and existing.client_session_id is not distinct from p_client_session_id then
    -- Same journey → PRESERVE the server-canonical start and finite deadline.
    v_started := existing.started_at;
    v_end     := existing.expected_end_at;
  else
    -- New journey → the server stamps the truth now.
    v_started := clock_timestamp();
    v_end     := case when coalesce(p_is_infinite, false) then null
                      else v_started + greatest(1, p_duration_seconds) * interval '1 second' end;
  end if;

  insert into public.active_flights
      (user_id, client_session_id, sky_id, balloon_skin_id, session_kind, focus_category,
       started_at, expected_end_at, paused_at, status, last_heartbeat_at, expires_at,
       sound_id)
  values (uid, p_client_session_id, p_sky_id, coalesce(nullif(p_balloon_skin_id, ''), 'default'),
          'public', coalesce(nullif(p_focus_category, ''), 'Focus'),
          v_started, v_end,
          case when coalesce(p_is_paused, false) then clock_timestamp() else null end,
          'active', clock_timestamp(), clock_timestamp() + interval '13 hours',
          -- Length-capped display key; the client maps it to a friendly name
          -- against the fixed catalog, so an unknown value simply shows nothing.
          left(nullif(p_sound_id, ''), 64))
  on conflict (user_id) do update
     set client_session_id = excluded.client_session_id,
         sky_id            = excluded.sky_id,
         balloon_skin_id   = excluded.balloon_skin_id,
         session_kind      = 'public',
         focus_category    = excluded.focus_category,
         started_at        = excluded.started_at,
         expected_end_at   = excluded.expected_end_at,
         paused_at         = excluded.paused_at,
         status            = 'active',
         last_heartbeat_at = excluded.last_heartbeat_at,
         expires_at        = excluded.expires_at,
         sound_id          = excluded.sound_id
  returning * into result;

  return jsonb_build_object('server_now',        clock_timestamp(),
                            'started_at',         result.started_at,
                            'expected_end_at',    result.expected_end_at,
                            'client_session_id',  result.client_session_id);
end $$;

revoke execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, text) from public, anon;
grant  execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 2. Applause events — a server-authorized, RLS-scoped, ephemeral ping stream.
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
end $$;

-- ----------------------------------------------------------------------------
-- 3. send_applause — the ONLY way to create an applause event. Enforces every
--    invariant server-side; the sender's alias is fetched here, never trusted
--    from the client. Returns {status:'sent'} or raises a precise token the app
--    maps to friendly UI. No rewards. Opportunistic cleanup keeps it tiny.
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
