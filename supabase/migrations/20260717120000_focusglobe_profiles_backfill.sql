-- ============================================================================
-- FocusGlobe Online — profile backfill + guaranteed profile existence.
-- Idempotent; safe to run once. PREREQUISITE: run the two prior migrations
-- (…_online.sql and …_online_pass2.sql) FIRST — this builds on their helpers.
--
-- ROOT CAUSE FIXED
--   focus_rooms.owner_id references profiles(id). The signup trigger
--   (on_auth_user_created → handle_new_user) is the ONLY guaranteed profile
--   creator, and it fires only on the FIRST auth.users insert. Apple Sign In
--   reuses the same auth.users row, so any user whose profiles row is missing
--   (removed during testing, or created before the trigger existed) never gets
--   one back on subsequent sign-ins. create_private_room then inserts
--   owner_id = auth.uid() with no matching profiles.id → FK 23503
--   (focus_rooms_owner_id_fkey). The foreign key is CORRECT and stays; the
--   fix is to guarantee the profile row always exists.
--
-- WHAT THIS DOES
--   1. private.ensure_profile(uid)      — creates the profile row if missing.
--   2. public.ensure_current_profile()  — callable by the app right after sign
--                                          in; ensures + returns the profile.
--   3. create_private_room / join_room_by_token — ensure the profile DEFENSIVELY
--                                          before any FK-bearing insert.
--   4. Backfill — every existing authenticated user missing a profile gets one.
-- The foreign key is never dropped or weakened.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. private.ensure_profile — the single guaranteed profile creator. Uses the
--    table defaults (unique-ish random alias, balloon_skin_id 'default',
--    is_discoverable false, allow_friend_requests true), exactly like the
--    signup trigger, so a created row is always constraint-valid. SECURITY
--    DEFINER + pinned search_path so it is never blocked by RLS.
-- ----------------------------------------------------------------------------
create or replace function private.ensure_profile(p_uid uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
begin
  if p_uid is null then return; end if;
  insert into public.profiles (id) values (p_uid) on conflict (id) do nothing;
end $$;

-- ----------------------------------------------------------------------------
-- 2. public.ensure_current_profile — the app calls this immediately after Sign
--    in with Apple succeeds (before Online becomes "ready") and on session
--    restore. Idempotent: creates the row if missing, then returns the
--    canonical profile as jsonb (same shape the client already decodes).
-- ----------------------------------------------------------------------------
create or replace function public.ensure_current_profile()
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid  uuid := auth.uid();
  prof public.profiles;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform private.ensure_profile(uid);
  select * into prof from public.profiles where id = uid;
  if prof.id is null then raise exception 'profile_unavailable'; end if;
  return to_jsonb(prof);
end $$;

-- ----------------------------------------------------------------------------
-- 3a. create_private_room — pass-2 body, plus a DEFENSIVE ensure_profile so a
--     profile-less user can never trip focus_rooms_owner_id_fkey (or the
--     room_members.user_id FK) again. This is the exact failure that was
--     reported; the ensure line is the server-side guarantee.
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
  perform private.ensure_profile(uid);          -- guarantee the owner FK target
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
-- 3b. join_room_by_token — pass-2 body, plus the same DEFENSIVE ensure_profile
--     (room_members.user_id also references profiles(id), so a profile-less
--     joiner would hit the identical FK class).
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
  perform private.ensure_profile(uid);          -- guarantee the member FK target
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
-- 4. Backfill — create a profile for every authenticated user that is missing
--    one (the orphaned accounts that produced the FK error). Column defaults
--    fill alias/skin/preferences, exactly like the trigger. Runs once; safe to
--    re-run (no-op afterwards).
-- ----------------------------------------------------------------------------
insert into public.profiles (id)
select u.id
  from auth.users u
  left join public.profiles p on p.id = u.id
 where p.id is null
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 5. Grants for the new RPC (create_private_room / join_room_by_token keep
--    their existing grants across CREATE OR REPLACE).
-- ----------------------------------------------------------------------------
grant execute on function public.ensure_current_profile() to authenticated;
revoke execute on function public.ensure_current_profile() from anon;
