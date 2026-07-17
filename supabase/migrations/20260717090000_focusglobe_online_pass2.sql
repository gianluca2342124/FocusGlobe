-- ============================================================================
-- FocusGlobe Online — pass 2 (correctness + UX contract).
-- Idempotent; safe to run once on the live database AFTER the first migration.
-- Existing legitimate rows are preserved.
--
-- Changes:
--  1. Room capacity becomes a server-defined 12 (host included). Existing
--     rooms keep their stored max_members; new rooms default to 12.
--  2. Invitation tokens become SINGLE-USE (one new pilot per token). Owners
--     and existing members opening a link never consume it.
--  3. join_room_by_token returns an explicit idempotent `membership` state:
--     'already_owner' / 'already_member' / 'joined'.
--  4. Room-mode presence: co-members of an active room may read each other's
--     active_flights row (synchronized remaining time in flight bubbles).
--     Public visibility rules are unchanged.
--  5. Stale lobby cleanup: expired rooms flip to 'expired' and their invites
--     are revoked opportunistically on room RPC entry.
--
-- NOTE (verified, no change needed):
--  • room_members already has PRIMARY KEY (room_id, user_id) — duplicates are
--    impossible at the database level.
--  • friend_requests already enforces sender <> receiver via CHECK constraint
--    AND the RLS insert policy (server-side self-request rejection).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Capacity: 12 total participants including the host.
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_constraint
             where conname = 'focus_rooms_max_members_check'
               and conrelid = 'public.focus_rooms'::regclass) then
    alter table public.focus_rooms drop constraint focus_rooms_max_members_check;
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'focus_rooms_max_members_check_v2'
                   and conrelid = 'public.focus_rooms'::regclass) then
    alter table public.focus_rooms
      add constraint focus_rooms_max_members_check_v2
      check (max_members between 2 and 12);
  end if;
end $$;

alter table public.focus_rooms alter column max_members set default 12;

-- ----------------------------------------------------------------------------
-- 2. Single-use invitations (new invites only; outstanding ones keep their
--    stored max_uses and still respect uses/expiry/revocation).
-- ----------------------------------------------------------------------------
alter table public.room_invites alter column max_uses set default 1;

-- ----------------------------------------------------------------------------
-- 3. Helpers: shared-active-room visibility + stale-room cleanup.
-- ----------------------------------------------------------------------------
create or replace function private.in_same_active_room(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1
      from public.room_members m1
      join public.room_members m2 on m1.room_id = m2.room_id
      join public.focus_rooms r   on r.id = m1.room_id
     where m1.user_id = a and m2.user_id = b
       and m1.status = 'joined' and m2.status = 'joined'
       and r.status in ('lobby','active')
       and r.expires_at > now());
$$;

-- Expire stale rooms + revoke their invitations. Bounded, cheap, idempotent.
create or replace function private.expire_stale_rooms()
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
begin
  update public.room_invites i set revoked_at = now()
   where i.revoked_at is null
     and exists (select 1 from public.focus_rooms r
                 where r.id = i.room_id
                   and (r.expires_at <= now() or r.status in ('closed','completed','expired')));
  update public.focus_rooms set status = 'expired'
   where status in ('lobby','active') and expires_at <= now();
end $$;

-- ----------------------------------------------------------------------------
-- 4. Room-mode presence visibility (active_flights).
--    Public rows: unchanged rules (fresh + discoverable + public + unblocked).
--    Room rows: visible ONLY to co-members of a shared active room.
-- ----------------------------------------------------------------------------
drop policy if exists active_flights_select on public.active_flights;
create policy active_flights_select on public.active_flights for select to authenticated
  using (user_id = auth.uid()
         or (status = 'active'
             and last_heartbeat_at > now() - interval '120 seconds'
             and session_kind = 'public'
             and private.is_discoverable(user_id)
             and not private.is_blocked_pair(user_id, auth.uid()))
         or (status = 'active'
             and last_heartbeat_at > now() - interval '120 seconds'
             and session_kind = 'room'
             and private.in_same_active_room(user_id, auth.uid())
             and not private.is_blocked_pair(user_id, auth.uid())));

-- ----------------------------------------------------------------------------
-- 5. join_room_by_token v2 — explicit idempotent membership result.
--    • Owner opening their own link: recognized, nothing inserted, nothing
--      consumed, no capacity taken → membership = 'already_owner'.
--    • Existing member reopening any link: nothing inserted, nothing
--      consumed → membership = 'already_member'.
--    • New pilot: seat + token consumed atomically → membership = 'joined'.
--    A consumed/expired/revoked/invalid token never creates a membership.
-- ----------------------------------------------------------------------------
create or replace function public.join_room_by_token(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  invite public.room_invites;
  room public.focus_rooms;
  member_count integer;
  membership text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform private.expire_stale_rooms();

  select * into invite from public.room_invites
   where token_hash = encode(extensions.digest(p_raw_token, 'sha256'), 'hex')
   for update;
  if invite.id is null then raise exception 'invite_invalid'; end if;

  select * into room from public.focus_rooms where id = invite.room_id for update;
  if room.id is null then raise exception 'room_not_found'; end if;

  -- Owner / existing member first: their access never depends on the token's
  -- remaining validity, and they must never consume it.
  if room.owner_id = uid then
    membership := 'already_owner';
    insert into public.room_members (room_id, user_id, role, status)
    values (room.id, uid, 'owner', 'joined')
    on conflict (room_id, user_id)
      do update set status = 'joined', left_at = null, last_heartbeat_at = now();
  elsif private.is_room_member(room.id, uid) then
    membership := 'already_member';
  else
    if invite.revoked_at is not null then raise exception 'invite_revoked'; end if;
    if invite.expires_at <= now() then raise exception 'invite_expired'; end if;
    if invite.uses >= invite.max_uses then raise exception 'invite_expired'; end if;
    if room.status not in ('lobby','active') or room.expires_at <= now() then
      raise exception 'room_closed';
    end if;
    if private.is_blocked_pair(room.owner_id, uid) then raise exception 'blocked'; end if;
    select count(*) into member_count from public.room_members
     where room_id = room.id and status = 'joined';
    if member_count >= room.max_members then raise exception 'room_full'; end if;
    insert into public.room_members (room_id, user_id, role, status)
    values (room.id, uid, 'member', 'joined')
    on conflict (room_id, user_id)
      do update set status = 'joined', left_at = null, last_heartbeat_at = now();
    update public.room_invites set uses = uses + 1 where id = invite.id;
    membership := 'joined';
  end if;

  if room.status not in ('lobby','active') or room.expires_at <= now() then
    raise exception 'room_closed';
  end if;

  return jsonb_build_object('room', private.room_payload(room),
                            'members', private.members_payload(room.id),
                            'membership', membership);
end $$;

-- ----------------------------------------------------------------------------
-- 5b. room_members_detailed — the AUTHORITATIVE participant list (alias +
--     skin + ready + heartbeat) for any member of a room. SECURITY DEFINER so
--     aliases are never lost to a client-side RLS/`in`-filter edge (this was
--     the "Sky Pilot everywhere" root cause: the client's direct profiles
--     query could return nothing and fall back to a literal). Non-members get
--     an empty array, never another user's data.
-- ----------------------------------------------------------------------------
create or replace function public.room_members_detailed(p_room_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not (exists (select 1 from public.focus_rooms where id = p_room_id and owner_id = uid)
          or private.is_room_member(p_room_id, uid)) then
    return '[]'::jsonb;
  end if;
  return private.members_payload(p_room_id);
end $$;

-- ----------------------------------------------------------------------------
-- 5c. set_room_flight_end — owner propagates the ACTUAL chosen flight duration
--     to the room once their real focus session begins, so every co-member's
--     bubble shows the SAME synchronized remaining time. Null ends_at = a
--     genuinely infinite flight (bubbles then read "Infinite", never faked).
-- ----------------------------------------------------------------------------
create or replace function public.set_room_flight_end(p_room_id uuid, p_ends_at timestamptz)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.focus_rooms
     set ends_at = p_ends_at,
         status = case when status = 'lobby' then 'active' else status end,
         starts_at = coalesce(starts_at, now()),
         expires_at = greatest(expires_at,
                               coalesce(p_ends_at, now()) + interval '2 hours')
   where id = p_room_id and owner_id = uid and status in ('lobby','active');
  if not found then raise exception 'not_owner'; end if;
end $$;

-- ----------------------------------------------------------------------------
-- 5d. send_friend_request — typed, idempotent, self-protected. Raises a stable
--     token the client maps to friendly copy (never the generic "didn't reach
--     the sky"): self / blocked / already_friends / requests_disabled /
--     duplicate / rate_limited.
-- ----------------------------------------------------------------------------
create or replace function public.send_friend_request(p_receiver_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_receiver_id = uid then raise exception 'self'; end if;
  if private.is_blocked_pair(uid, p_receiver_id) then raise exception 'blocked'; end if;
  if private.are_friends(uid, p_receiver_id) then raise exception 'already_friends'; end if;
  if not private.allows_requests(p_receiver_id) then raise exception 'requests_disabled'; end if;
  if exists (select 1 from public.friend_requests
             where sender_id = uid and created_at > now() - interval '10 seconds') then
    raise exception 'rate_limited';
  end if;
  if exists (select 1 from public.friend_requests
             where status = 'pending'
               and ((sender_id = uid and receiver_id = p_receiver_id)
                 or (sender_id = p_receiver_id and receiver_id = uid))) then
    raise exception 'duplicate';
  end if;
  insert into public.friend_requests (sender_id, receiver_id) values (uid, p_receiver_id);
end $$;

-- ----------------------------------------------------------------------------
-- 6. create_private_room v2 — unchanged contract plus stale cleanup on entry
--    and an explicit membership flag for symmetry. New rooms default to 12.
-- ----------------------------------------------------------------------------
create or replace function public.create_private_room(p_sky_id text, p_duration_seconds integer default null,
                                                      p_purpose text default 'flight')
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  room public.focus_rooms;
  raw_token text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_purpose not in ('flight','sky_unlock') then raise exception 'invalid_reason'; end if;
  perform private.expire_stale_rooms();
  if (select count(*) from public.focus_rooms
      where owner_id = uid and created_at > now() - interval '10 minutes') >= 5 then
    raise exception 'rate_limited';
  end if;

  select * into room from public.focus_rooms
   where owner_id = uid and sky_id = p_sky_id and purpose = p_purpose
     and status = 'lobby' and expires_at > now()
     and created_at > now() - interval '15 minutes'
   order by created_at desc limit 1
   for update;

  if room.id is null then
    insert into public.focus_rooms (owner_id, sky_id, purpose, duration_seconds)
    values (uid, p_sky_id, p_purpose, p_duration_seconds)
    returning * into room;
  end if;

  insert into public.room_members (room_id, user_id, role, status)
  values (room.id, uid, 'owner', 'joined')
  on conflict (room_id, user_id)
    do update set status = 'joined', left_at = null, last_heartbeat_at = now();

  raw_token := private.new_invite(room.id, uid);

  return jsonb_build_object('room', private.room_payload(room),
                            'members', private.members_payload(room.id),
                            'invite_token', raw_token,
                            'membership', 'already_owner');
end $$;

-- ----------------------------------------------------------------------------
-- 7. Grants. (create_private_room / join_room_by_token keep their existing
--    grants across CREATE OR REPLACE; only the NEW function needs one.)
-- ----------------------------------------------------------------------------
grant execute on function public.room_members_detailed(uuid) to authenticated;
grant execute on function public.set_room_flight_end(uuid, timestamptz) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
revoke execute on function public.room_members_detailed(uuid) from anon;
revoke execute on function public.set_room_flight_end(uuid, timestamptz) from anon;
revoke execute on function public.send_friend_request(uuid) from anon;
