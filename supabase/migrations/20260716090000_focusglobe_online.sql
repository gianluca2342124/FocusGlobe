-- ============================================================================
-- FocusGlobe Online — complete Supabase backend (replaces CloudKit social).
-- Container-free, quota-free. Run in the Supabase SQL Editor or via
-- `supabase db push`. Idempotent where practical (IF NOT EXISTS / OR REPLACE).
--
-- Design rules enforced here:
--  • RLS ENABLED on every table; no `using (true)` write policies anywhere.
--  • All room / friendship / reward mutations flow through SECURITY DEFINER
--    RPCs with auth.uid() as the only identity source.
--  • Invite tokens are stored ONLY as SHA-256 hashes; raw tokens are returned
--    exactly once from the creating RPC.
--  • The client never supplies reward amounts; the server computes them.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

-- ----------------------------------------------------------------------------
-- Private helper schema (SECURITY DEFINER helpers keep RLS policies
-- non-recursive and centralize relationship checks).
-- ----------------------------------------------------------------------------
create schema if not exists private;

-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- 1) profiles — one row per auth user. Public face is anonymous by design.
create table if not exists public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  public_alias          text not null default ('SkyPilot' || floor(random() * 9000 + 1000)::int),
  country_code          text,
  balloon_skin_id       text not null default 'default',
  is_discoverable       boolean not null default false,
  allow_friend_requests boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  last_seen_at          timestamptz,
  constraint profiles_alias_len check (char_length(public_alias) between 3 and 20)
);

-- 2) active_flights — durable discoverability for public skies (one per user).
create table if not exists public.active_flights (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null unique references public.profiles(id) on delete cascade,
  sky_id           text not null,
  balloon_skin_id  text not null default 'default',
  session_kind     text not null default 'public' check (session_kind in ('public','room')),
  focus_category   text not null default 'Focus',
  started_at       timestamptz not null default now(),
  expected_end_at  timestamptz,
  paused_at        timestamptz,
  status           text not null default 'active' check (status in ('active','ended')),
  last_heartbeat_at timestamptz not null default now(),
  expires_at       timestamptz not null default (now() + interval '13 hours')
);

-- 3) friend_requests
create table if not exists public.friend_requests (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  receiver_id  uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  constraint friend_requests_not_self check (sender_id <> receiver_id)
);
create unique index if not exists friend_requests_pending_pair
  on public.friend_requests (sender_id, receiver_id) where (status = 'pending');

-- 4) friendships — canonical ordered pair (user_low < user_high).
create table if not exists public.friendships (
  id         uuid primary key default gen_random_uuid(),
  user_low   uuid not null references public.profiles(id) on delete cascade,
  user_high  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint friendships_ordered check (user_low < user_high),
  constraint friendships_unique unique (user_low, user_high)
);

-- 5) blocks
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

-- 6) pilot_reports — write-only for clients; reviewed out-of-band.
create table if not exists public.pilot_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reason      text not null check (reason in
                ('Inappropriate alias','Harassment or bullying','Spam','Something else')),
  status      text not null default 'open' check (status in ('open','reviewed','dismissed')),
  created_at  timestamptz not null default now(),
  constraint pilot_reports_not_self check (reporter_id <> reported_id)
);

-- 7) focus_rooms — private rooms; ALL writes via RPC.
create table if not exists public.focus_rooms (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references public.profiles(id) on delete cascade,
  sky_id           text not null,
  purpose          text not null default 'flight' check (purpose in ('flight','sky_unlock')),
  duration_seconds integer check (duration_seconds is null or duration_seconds between 60 and 43200),
  status           text not null default 'lobby' check (status in ('lobby','active','completed','closed','expired')),
  max_members      integer not null default 8 check (max_members between 2 and 8),
  starts_at        timestamptz,
  ends_at          timestamptz,
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null default (now() + interval '24 hours')
);

-- 8) room_members
create table if not exists public.room_members (
  room_id           uuid not null references public.focus_rooms(id) on delete cascade,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  role              text not null default 'member' check (role in ('owner','member')),
  status            text not null default 'joined' check (status in ('joined','left','removed')),
  is_ready          boolean not null default false,
  joined_at         timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  left_at           timestamptz,
  primary key (room_id, user_id)
);

-- 9) room_invites — token HASHES only; validation via RPC exclusively.
create table if not exists public.room_invites (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.focus_rooms(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null default (now() + interval '48 hours'),
  max_uses   integer not null default 8 check (max_uses between 1 and 32),
  uses       integer not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

-- 10) online_sessions — one per member per started room flight (server-created).
create table if not exists public.online_sessions (
  id                uuid primary key default gen_random_uuid(),
  room_id           uuid references public.focus_rooms(id) on delete set null,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  started_at        timestamptz not null default now(),
  expected_end_at   timestamptz,
  completed_at      timestamptz,
  focused_seconds   integer not null default 0,
  status            text not null default 'active' check (status in ('active','completed','abandoned')),
  reward_claimed_at timestamptz
);

-- 11) online_reward_claims — server-computed, idempotent ledger.
create table if not exists public.online_reward_claims (
  id              uuid primary key default gen_random_uuid(),
  session_id      uuid not null references public.online_sessions(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  reward_type     text not null check (reward_type in ('friend_bonus')),
  amount          integer not null check (amount >= 0),
  idempotency_key text not null unique,
  created_at      timestamptz not null default now()
);

-- ============================================================================
-- 2. INDEXES
-- ============================================================================
create index if not exists profiles_discoverable_idx   on public.profiles (is_discoverable) where is_discoverable;
create index if not exists active_flights_sky_idx      on public.active_flights (sky_id, last_heartbeat_at desc);
create index if not exists active_flights_stale_idx    on public.active_flights (last_heartbeat_at);
create index if not exists active_flights_expires_idx  on public.active_flights (expires_at);
create index if not exists friend_requests_receiver_idx on public.friend_requests (receiver_id, status, created_at desc);
create index if not exists friend_requests_sender_idx  on public.friend_requests (sender_id, status, created_at desc);
create index if not exists friendships_low_idx         on public.friendships (user_low);
create index if not exists friendships_high_idx        on public.friendships (user_high);
create index if not exists blocks_blocked_idx          on public.blocks (blocked_id);
create index if not exists pilot_reports_reported_idx  on public.pilot_reports (reported_id, created_at desc);
create index if not exists pilot_reports_reporter_idx  on public.pilot_reports (reporter_id, created_at desc);
create index if not exists focus_rooms_owner_idx       on public.focus_rooms (owner_id, status, created_at desc);
create index if not exists focus_rooms_expiry_idx      on public.focus_rooms (expires_at) where status in ('lobby','active');
create index if not exists room_members_user_idx       on public.room_members (user_id, status);
create index if not exists room_members_heartbeat_idx  on public.room_members (room_id, last_heartbeat_at desc);
create index if not exists room_invites_room_idx       on public.room_invites (room_id);
create index if not exists online_sessions_user_idx    on public.online_sessions (user_id, status, started_at desc);
create index if not exists online_sessions_room_idx    on public.online_sessions (room_id);

-- ============================================================================
-- 3. TRIGGERS — updated_at + auto-profile on signup + request rate limit
-- ============================================================================
create or replace function private.set_updated_at()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- Auto-create an anonymous profile for every new auth user.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Friend-request rate limit: 1 per 10 s, 20 per hour.
create or replace function private.friend_request_rate_limit()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if exists (select 1 from public.friend_requests
             where sender_id = new.sender_id and created_at > now() - interval '10 seconds') then
    raise exception 'rate_limited';
  end if;
  if (select count(*) from public.friend_requests
      where sender_id = new.sender_id and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'rate_limited';
  end if;
  return new;
end $$;

drop trigger if exists friend_requests_rate_limit on public.friend_requests;
create trigger friend_requests_rate_limit before insert on public.friend_requests
  for each row execute function private.friend_request_rate_limit();

-- ============================================================================
-- 4. RELATIONSHIP HELPERS (SECURITY DEFINER; used inside RLS policies)
-- ============================================================================
create or replace function private.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.friendships
                 where user_low = least(a, b) and user_high = greatest(a, b));
$$;

create or replace function private.is_blocked_pair(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.blocks
                 where (blocker_id = a and blocked_id = b)
                    or (blocker_id = b and blocked_id = a));
$$;

create or replace function private.is_room_member(p_room uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.room_members
                 where room_id = p_room and user_id = p_user and status = 'joined');
$$;

create or replace function private.is_discoverable(p_user uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select is_discoverable from public.profiles where id = p_user), false);
$$;

create or replace function private.allows_requests(p_user uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select allow_friend_requests from public.profiles where id = p_user), false);
$$;

-- Profile visibility: self, discoverable, friends, co-members, request pair.
create or replace function private.can_view_profile(p_target uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select p_target = p_viewer
      or private.is_discoverable(p_target)
      or private.are_friends(p_target, p_viewer)
      or exists (select 1 from public.room_members m1
                 join public.room_members m2 on m1.room_id = m2.room_id
                 where m1.user_id = p_target and m2.user_id = p_viewer
                   and m1.status = 'joined' and m2.status = 'joined')
      or exists (select 1 from public.friend_requests r
                 where (r.sender_id = p_target and r.receiver_id = p_viewer)
                    or (r.sender_id = p_viewer and r.receiver_id = p_target));
$$;

-- ============================================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles             enable row level security;
alter table public.active_flights       enable row level security;
alter table public.friend_requests      enable row level security;
alter table public.friendships          enable row level security;
alter table public.blocks               enable row level security;
alter table public.pilot_reports        enable row level security;
alter table public.focus_rooms          enable row level security;
alter table public.room_members         enable row level security;
alter table public.room_invites         enable row level security;
alter table public.online_sessions      enable row level security;
alter table public.online_reward_claims enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (private.can_view_profile(id, auth.uid()) and not private.is_blocked_pair(id, auth.uid()));
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- active_flights
drop policy if exists active_flights_select on public.active_flights;
create policy active_flights_select on public.active_flights for select to authenticated
  using (user_id = auth.uid()
         or (status = 'active'
             and last_heartbeat_at > now() - interval '120 seconds'
             and session_kind = 'public'
             and private.is_discoverable(user_id)
             and not private.is_blocked_pair(user_id, auth.uid())));
drop policy if exists active_flights_insert on public.active_flights;
create policy active_flights_insert on public.active_flights for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists active_flights_update on public.active_flights;
create policy active_flights_update on public.active_flights for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists active_flights_delete on public.active_flights;
create policy active_flights_delete on public.active_flights for delete to authenticated
  using (user_id = auth.uid());

-- friend_requests (insert direct+policy; answer/cancel via RPC only)
drop policy if exists friend_requests_select on public.friend_requests;
create policy friend_requests_select on public.friend_requests for select to authenticated
  using (sender_id = auth.uid() or receiver_id = auth.uid());
drop policy if exists friend_requests_insert on public.friend_requests;
create policy friend_requests_insert on public.friend_requests for insert to authenticated
  with check (sender_id = auth.uid()
              and sender_id <> receiver_id
              and status = 'pending'
              and not private.is_blocked_pair(sender_id, receiver_id)
              and not private.are_friends(sender_id, receiver_id)
              and private.allows_requests(receiver_id)
              and not exists (select 1 from public.friend_requests r
                              where r.sender_id = receiver_id and r.receiver_id = sender_id
                                and r.status = 'pending'));

-- friendships (read own pairs; writes RPC-only)
drop policy if exists friendships_select on public.friendships;
create policy friendships_select on public.friendships for select to authenticated
  using (user_low = auth.uid() or user_high = auth.uid());

-- blocks (blocker-owned)
drop policy if exists blocks_select on public.blocks;
create policy blocks_select on public.blocks for select to authenticated
  using (blocker_id = auth.uid());
drop policy if exists blocks_insert on public.blocks;
create policy blocks_insert on public.blocks for insert to authenticated
  with check (blocker_id = auth.uid());
drop policy if exists blocks_delete on public.blocks;
create policy blocks_delete on public.blocks for delete to authenticated
  using (blocker_id = auth.uid());

-- pilot_reports: RPC-only (no client policies at all)

-- focus_rooms (read for members; writes RPC-only)
drop policy if exists focus_rooms_select on public.focus_rooms;
create policy focus_rooms_select on public.focus_rooms for select to authenticated
  using (owner_id = auth.uid() or private.is_room_member(id, auth.uid()));

-- room_members (read co-members; heartbeat/ready column-update on own row)
drop policy if exists room_members_select on public.room_members;
create policy room_members_select on public.room_members for select to authenticated
  using (user_id = auth.uid() or private.is_room_member(room_id, auth.uid()));
drop policy if exists room_members_update on public.room_members;
create policy room_members_update on public.room_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- room_invites: RPC-only (not enumerable; no client policies at all)

-- online_sessions (read own; writes RPC-only)
drop policy if exists online_sessions_select on public.online_sessions;
create policy online_sessions_select on public.online_sessions for select to authenticated
  using (user_id = auth.uid());

-- online_reward_claims (read own; writes RPC-only)
drop policy if exists online_reward_claims_select on public.online_reward_claims;
create policy online_reward_claims_select on public.online_reward_claims for select to authenticated
  using (user_id = auth.uid());

-- ============================================================================
-- 6. PRIVILEGES — anon gets nothing; RPC-only tables lose direct writes.
-- ============================================================================
revoke all on all tables in schema public from anon;
revoke all on public.focus_rooms          from authenticated;
revoke all on public.room_invites         from authenticated;
revoke all on public.friendships          from authenticated;
revoke all on public.online_sessions      from authenticated;
revoke all on public.online_reward_claims from authenticated;
revoke all on public.pilot_reports        from authenticated;
revoke all on public.room_members         from authenticated;
revoke delete on public.profiles          from authenticated;
revoke update, delete on public.friend_requests from authenticated;

grant select on public.focus_rooms          to authenticated;
grant select on public.friendships          to authenticated;
grant select on public.online_sessions      to authenticated;
grant select on public.online_reward_claims to authenticated;
grant select on public.room_members         to authenticated;
grant update (is_ready, last_heartbeat_at) on public.room_members to authenticated;

-- ============================================================================
-- 7. RPC FUNCTIONS (SECURITY DEFINER, auth.uid() identity, stable error codes)
--    Error messages are single tokens the Swift client maps to friendly copy:
--    not_authenticated / rate_limited / room_full / room_not_found /
--    room_closed / invite_invalid / invite_expired / invite_revoked /
--    blocked / not_owner / not_member / request_not_found / already_friends /
--    invalid_reason / session_not_found
-- ============================================================================

-- Canonical room payload (UTC millisecond timestamps for stable Swift parsing).
create or replace function private.room_payload(r public.focus_rooms)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', r.id, 'owner_id', r.owner_id, 'sky_id', r.sky_id, 'purpose', r.purpose,
    'status', r.status, 'duration_seconds', r.duration_seconds, 'max_members', r.max_members,
    'starts_at',  to_char(r.starts_at  at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'ends_at',    to_char(r.ends_at    at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'created_at', to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'expires_at', to_char(r.expires_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
$$;

create or replace function private.members_payload(p_room uuid)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', m.user_id, 'role', m.role, 'status', m.status,
           'is_ready', m.is_ready,
           'joined_at', to_char(m.joined_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'last_heartbeat_at', to_char(m.last_heartbeat_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'alias', p.public_alias, 'balloon_skin_id', p.balloon_skin_id,
           'country_code', p.country_code) order by m.joined_at), '[]'::jsonb)
  from public.room_members m join public.profiles p on p.id = m.user_id
  where m.room_id = p_room and m.status = 'joined';
$$;

create or replace function private.new_invite(p_room uuid, p_user uuid)
returns text language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  raw text;
begin
  raw := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_');
  raw := replace(raw, chr(10), '');
  insert into public.room_invites (room_id, created_by, token_hash)
  values (p_room, p_user, encode(extensions.digest(raw, 'sha256'), 'hex'));
  return raw;
end $$;

-- create_private_room: single transaction; reuses a fresh lobby (anti-double-
-- tap); owner membership; fresh one-time invite token in the response.
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
                            'invite_token', raw_token);
end $$;

create or replace function public.create_room_invite(p_room_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  room public.focus_rooms;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into room from public.focus_rooms where id = p_room_id for update;
  if room.id is null then raise exception 'room_not_found'; end if;
  if room.owner_id <> uid then raise exception 'not_owner'; end if;
  if room.status not in ('lobby','active') or room.expires_at <= now() then
    raise exception 'room_closed';
  end if;
  if (select count(*) from public.room_invites
      where created_by = uid and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'rate_limited';
  end if;
  return jsonb_build_object('invite_token', private.new_invite(room.id, uid));
end $$;

create or replace function public.join_room_by_token(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  invite public.room_invites;
  room public.focus_rooms;
  member_count integer;
  already boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into invite from public.room_invites
   where token_hash = encode(extensions.digest(p_raw_token, 'sha256'), 'hex')
   for update;
  if invite.id is null then raise exception 'invite_invalid'; end if;
  if invite.revoked_at is not null then raise exception 'invite_revoked'; end if;
  if invite.expires_at <= now() then raise exception 'invite_expired'; end if;

  select * into room from public.focus_rooms where id = invite.room_id for update;
  if room.id is null then raise exception 'room_not_found'; end if;
  if room.status not in ('lobby','active') or room.expires_at <= now() then
    raise exception 'room_closed';
  end if;
  if private.is_blocked_pair(room.owner_id, uid) then raise exception 'blocked'; end if;

  already := private.is_room_member(room.id, uid);
  if not already then
    if invite.uses >= invite.max_uses then raise exception 'invite_expired'; end if;
    select count(*) into member_count from public.room_members
     where room_id = room.id and status = 'joined';
    if member_count >= room.max_members then raise exception 'room_full'; end if;
    insert into public.room_members (room_id, user_id, role, status)
    values (room.id, uid, 'member', 'joined')
    on conflict (room_id, user_id)
      do update set status = 'joined', left_at = null, last_heartbeat_at = now();
    update public.room_invites set uses = uses + 1 where id = invite.id;
  end if;

  return jsonb_build_object('room', private.room_payload(room),
                            'members', private.members_payload(room.id));
end $$;

create or replace function public.set_room_ready(p_room_id uuid, p_ready boolean)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.room_members set is_ready = p_ready, last_heartbeat_at = now()
   where room_id = p_room_id and user_id = uid and status = 'joined';
  if not found then raise exception 'not_member'; end if;
end $$;

create or replace function public.start_private_room(p_room_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  room public.focus_rooms;
  member record;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into room from public.focus_rooms where id = p_room_id for update;
  if room.id is null then raise exception 'room_not_found'; end if;
  if room.owner_id <> uid then raise exception 'not_owner'; end if;
  if room.status = 'active' then
    return jsonb_build_object('room', private.room_payload(room),
                              'members', private.members_payload(room.id));
  end if;
  if room.status <> 'lobby' or room.expires_at <= now() then raise exception 'room_closed'; end if;
  if not private.is_room_member(room.id, uid) then raise exception 'not_member'; end if;

  update public.focus_rooms
     set status = 'active', starts_at = now(),
         ends_at = case when duration_seconds is not null
                        then now() + make_interval(secs => duration_seconds) end,
         expires_at = greatest(expires_at, now() + interval '14 hours')
   where id = room.id
   returning * into room;

  for member in select user_id from public.room_members
                 where room_id = room.id and status = 'joined' loop
    insert into public.online_sessions (room_id, user_id, started_at, expected_end_at)
    values (room.id, member.user_id, room.starts_at, room.ends_at);
  end loop;

  return jsonb_build_object('room', private.room_payload(room),
                            'members', private.members_payload(room.id));
end $$;

create or replace function public.leave_private_room(p_room_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  room public.focus_rooms;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into room from public.focus_rooms where id = p_room_id for update;
  if room.id is null then raise exception 'room_not_found'; end if;
  update public.room_members set status = 'left', left_at = now()
   where room_id = p_room_id and user_id = uid and status = 'joined';
  if room.owner_id = uid and room.status in ('lobby','active') then
    update public.focus_rooms set status = 'closed' where id = room.id;
  end if;
end $$;

create or replace function public.remove_room_member(p_room_id uuid, p_user_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.focus_rooms where id = p_room_id and owner_id = uid) then
    raise exception 'not_owner';
  end if;
  if p_user_id = uid then raise exception 'not_member'; end if;
  update public.room_members set status = 'removed', left_at = now()
   where room_id = p_room_id and user_id = p_user_id and status = 'joined';
end $$;

create or replace function public.close_private_room(p_room_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.focus_rooms set status = 'closed'
   where id = p_room_id and owner_id = uid and status in ('lobby','active');
  if not found then raise exception 'not_owner'; end if;
  update public.room_invites set revoked_at = now()
   where room_id = p_room_id and revoked_at is null;
end $$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  req public.friend_requests;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into req from public.friend_requests where id = p_request_id for update;
  if req.id is null or req.receiver_id <> uid then raise exception 'request_not_found'; end if;
  if req.status <> 'pending' then raise exception 'request_not_found'; end if;
  if private.is_blocked_pair(req.sender_id, req.receiver_id) then raise exception 'blocked'; end if;
  update public.friend_requests set status = 'accepted', responded_at = now() where id = req.id;
  insert into public.friendships (user_low, user_high)
  values (least(req.sender_id, req.receiver_id), greatest(req.sender_id, req.receiver_id))
  on conflict (user_low, user_high) do nothing;
end $$;

create or replace function public.decline_friend_request(p_request_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.friend_requests set status = 'declined', responded_at = now()
   where id = p_request_id and receiver_id = uid and status = 'pending';
  if not found then raise exception 'request_not_found'; end if;
end $$;

create or replace function public.cancel_friend_request(p_request_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  delete from public.friend_requests
   where id = p_request_id and sender_id = uid and status = 'pending';
  if not found then raise exception 'request_not_found'; end if;
end $$;

create or replace function public.remove_friend(p_friend_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  delete from public.friendships
   where user_low = least(uid, p_friend_id) and user_high = greatest(uid, p_friend_id);
end $$;

create or replace function public.block_user(p_user_id uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_user_id = uid then raise exception 'blocked'; end if;
  insert into public.blocks (blocker_id, blocked_id) values (uid, p_user_id)
  on conflict (blocker_id, blocked_id) do nothing;
  delete from public.friendships
   where user_low = least(uid, p_user_id) and user_high = greatest(uid, p_user_id);
  update public.friend_requests set status = 'cancelled', responded_at = now()
   where status = 'pending'
     and ((sender_id = uid and receiver_id = p_user_id)
       or (sender_id = p_user_id and receiver_id = uid));
end $$;

create or replace function public.report_pilot(p_user_id uuid, p_reason text)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_user_id = uid then raise exception 'invalid_reason'; end if;
  if p_reason not in ('Inappropriate alias','Harassment or bullying','Spam','Something else') then
    raise exception 'invalid_reason';
  end if;
  if (select count(*) from public.pilot_reports
      where reporter_id = uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'rate_limited';
  end if;
  insert into public.pilot_reports (reporter_id, reported_id, reason)
  values (uid, p_user_id, p_reason);
end $$;

-- Server-verified session completion. Overlap and the friend bonus are
-- computed here from server rows; the client NEVER sends amounts. Amount is
-- verified overlap minutes, capped at 480 — the app applies its own local
-- FocusEconomy multiplier using this verification.
create or replace function public.complete_online_session(p_session_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  session public.online_sessions;
  my_end timestamptz;
  overlap_seconds integer := 0;
  other record;
  bonus boolean := false;
  claim_amount integer := 0;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into session from public.online_sessions
   where id = p_session_id and user_id = uid for update;
  if session.id is null then raise exception 'session_not_found'; end if;

  if session.completed_at is not null then
    return jsonb_build_object('focused_seconds', session.focused_seconds,
      'friend_bonus', exists (select 1 from public.online_reward_claims
                              where session_id = session.id and reward_type = 'friend_bonus'),
      'amount', coalesce((select amount from public.online_reward_claims
                          where session_id = session.id and reward_type = 'friend_bonus'), 0));
  end if;

  my_end := least(now(), coalesce(session.expected_end_at, now()));
  update public.online_sessions
     set completed_at = now(), status = 'completed',
         focused_seconds = greatest(0, extract(epoch from (my_end - started_at))::integer)
   where id = session.id
   returning * into session;

  if session.room_id is not null then
    for other in
      select s.started_at, coalesce(s.completed_at, m.last_heartbeat_at) as ended
        from public.online_sessions s
        join public.room_members m on m.room_id = s.room_id and m.user_id = s.user_id
       where s.room_id = session.room_id and s.user_id <> uid
    loop
      overlap_seconds := greatest(overlap_seconds, greatest(0, extract(epoch from (
        least(coalesce(session.completed_at, now()), other.ended)
        - greatest(session.started_at, other.started_at)))::integer));
    end loop;
    if overlap_seconds >= 300 then
      bonus := true;
      claim_amount := least(session.focused_seconds / 60, 480);
      insert into public.online_reward_claims (session_id, user_id, reward_type, amount, idempotency_key)
      values (session.id, uid, 'friend_bonus', claim_amount, 'friend-bonus-' || session.id)
      on conflict (idempotency_key) do nothing;
      update public.online_sessions set reward_claimed_at = now() where id = session.id;
    end if;
  end if;

  return jsonb_build_object('focused_seconds', session.focused_seconds,
                            'friend_bonus', bonus, 'amount', claim_amount);
end $$;

-- Full online-data erasure (profile row included; local app data untouched).
create or replace function public.delete_my_online_data()
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  delete from public.active_flights where user_id = uid;
  update public.focus_rooms set status = 'closed'
   where owner_id = uid and status in ('lobby','active');
  update public.room_invites set revoked_at = now()
   where created_by = uid and revoked_at is null;
  update public.room_members set status = 'left', left_at = now()
   where user_id = uid and status = 'joined';
  delete from public.friend_requests where sender_id = uid or receiver_id = uid;
  delete from public.friendships where user_low = uid or user_high = uid;
  delete from public.online_sessions where user_id = uid;
  delete from public.profiles where id = uid;
end $$;

-- Sky-unlock campaign progress: verified joins (not link opens) of the owner's
-- sky_unlock rooms, deduplicated by account.
create or replace function public.campaign_progress(p_sky_id text)
returns integer language sql stable security definer set search_path = public, pg_temp as $$
  select count(distinct m.user_id)::integer
    from public.room_members m
    join public.focus_rooms r on r.id = m.room_id
   where r.owner_id = auth.uid() and r.purpose = 'sky_unlock'
     and r.sky_id = p_sky_id and m.user_id <> auth.uid() and m.status = 'joined';
$$;

grant execute on function
  public.create_private_room(text, integer, text),
  public.create_room_invite(uuid),
  public.join_room_by_token(text),
  public.set_room_ready(uuid, boolean),
  public.start_private_room(uuid),
  public.leave_private_room(uuid),
  public.remove_room_member(uuid, uuid),
  public.close_private_room(uuid),
  public.accept_friend_request(uuid),
  public.decline_friend_request(uuid),
  public.cancel_friend_request(uuid),
  public.remove_friend(uuid),
  public.block_user(uuid),
  public.report_pilot(uuid, text),
  public.complete_online_session(uuid),
  public.delete_my_online_data(),
  public.campaign_progress(text)
to authenticated;

revoke execute on all functions in schema public from anon;

-- ============================================================================
-- 8. REALTIME — lobby + room + flights change feeds (RLS-authorized).
-- ============================================================================
alter table public.room_members   replica identity full;
alter table public.focus_rooms    replica identity full;
alter table public.active_flights replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.focus_rooms;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.room_members;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.active_flights;
  exception when duplicate_object then null;
  end;
end $$;
