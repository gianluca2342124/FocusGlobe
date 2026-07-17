-- ============================================================================
-- FocusGlobe Online — Global→Private promotion of an ALREADY-ACTIVE flight.
-- Idempotent; safe to run once. PREREQUISITE: the three prior migrations
-- (…_online, …_online_pass2, …_profiles_backfill) must already be applied.
--
-- WHY THIS EXISTS
--   The host is already focusing in an active Global Flight when they tap
--   Invite Friends. This is NOT a pre-flight lobby: the flight has already taken
--   off. create_private_room can only mint a room in the artificial 'lobby'
--   state and its reuse only matches 'lobby' rooms — so once a room is flipped
--   'active', a second Invite tap would create a DUPLICATE room. That is the
--   wrong representation.
--
--   promote_global_flight_to_private() represents the correct state directly:
--   an ACTIVE private flight that carries the host's canonical server
--   timestamps, is reused idempotently for repeated Invite taps in the SAME
--   journey (keyed by the client session id), creates exactly one owner
--   membership, and returns a fresh single-use invitation. Guests join it with
--   the existing join_room_by_token and inherit its ends_at (synchronized
--   remaining time). auth.uid() is authoritative — the owner is never trusted
--   from the client.
-- ============================================================================

-- One nullable key so repeated Invite taps in a single journey reuse ONE flight.
alter table public.focus_rooms add column if not exists client_session_id text;
create index if not exists focus_rooms_client_session_idx
  on public.focus_rooms (owner_id, client_session_id)
  where client_session_id is not null;

create or replace function public.promote_global_flight_to_private(
    p_client_session_id text,
    p_sky_id            text,
    p_ends_at           timestamptz,
    p_started_at        timestamptz)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  room public.focus_rooms;
  raw_token text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  perform private.ensure_profile(uid);       -- guarantee the owner FK target
  perform private.expire_stale_rooms();

  -- Reuse the SAME active private flight for repeated Invite taps in one
  -- journey — never a duplicate room/session.
  select * into room from public.focus_rooms
   where owner_id = uid
     and client_session_id = p_client_session_id
     and status = 'active'
     and expires_at > now()
   for update;

  if room.id is null then
    -- Born ACTIVE (never a lobby), with the host's canonical timestamps.
    insert into public.focus_rooms
        (owner_id, sky_id, purpose, status, client_session_id,
         starts_at, ends_at, expires_at)
    values (uid, p_sky_id, 'flight', 'active', p_client_session_id,
            coalesce(p_started_at, now()), p_ends_at,
            greatest(now() + interval '2 hours', coalesce(p_ends_at, now()) + interval '2 hours'))
    returning * into room;
  else
    -- Keep the shared end current (the host's remaining shrinks over time).
    update public.focus_rooms
       set ends_at = p_ends_at,
           sky_id = p_sky_id,
           expires_at = greatest(expires_at, coalesce(p_ends_at, now()) + interval '2 hours')
     where id = room.id
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

grant execute on function public.promote_global_flight_to_private(text, text, timestamptz, timestamptz) to authenticated;
revoke execute on function public.promote_global_flight_to_private(text, text, timestamptz, timestamptz) from anon;
