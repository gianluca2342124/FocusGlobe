-- ============================================================================
-- FocusGlobe Online — GLOBALLY UNIQUE PUBLIC ALIAS
--
-- WHY THIS EXISTS
--   `profiles.public_alias` is the name other pilots see, and it is now also the
--   one canonical name the app shows its own user. Nothing has ever stopped two
--   accounts owning it. The table has a length check and a random default and
--   that is all — so "Alex", "alex" and " ALEX " could be three different people
--   who all appear identical in a Public Sky, a room member list and a friend
--   request.
--
--   A client-side "is this free?" query followed by an UPDATE cannot fix that:
--   two devices can both read "free" before either writes. Only the database can
--   settle it, so this puts the guarantee where it belongs.
--
-- WHAT THIS DOES
--   1. Repairs blank aliases and existing case-insensitive duplicates,
--      deterministically and without deleting or regenerating anything that is
--      already unique.
--   2. Adds a case- and whitespace-insensitive UNIQUE index.
--   3. Teaches `private.ensure_profile` to retry on collision — it is called
--      defensively from half a dozen RPCs, and the 9,000-value random default it
--      relied on would now be able to make those RPCs throw.
--   4. Adds `public.claim_public_alias(text)`: one atomic UPDATE that either
--      takes the name or reports it taken. No check-then-act, no race.
--
-- SAFETY
--   Idempotent, and ordered so the index is only created against data already
--   known to satisfy it. No profile is deleted. No alias that is already unique
--   is rewritten. Supabase UUIDs remain the account identity; nothing here
--   touches auth, RevenueCat or any other table.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. private.random_alias — THE generated-alias source, server side.
--
--    Word pairs rather than digits: "QuietComet" is readable, neutral, carries
--    nothing personal, and does not look like a UUID. 15 x 15 = 225 bare pairs;
--    a two-digit tail only appears once collisions have actually bitten, which
--    takes the space to ~20,000 without making the common case ugly.
-- ----------------------------------------------------------------------------
create or replace function private.random_alias(p_attempt int default 0)
returns text language plpgsql volatile set search_path = public, pg_temp as $$
declare
  adjectives text[] := array[
    'Quiet','Silver','Calm','Blue','Soft','Bright','Still','Golden',
    'Gentle','Northern','Amber','Silent','Clear','Warm','Distant'];
  nouns text[] := array[
    'Comet','Cloud','Orbit','Lantern','Horizon','Drift','Ember','Meridian',
    'Compass','Beacon','Summit','Current','Aurora','Harbor','Voyage'];
  base text;
begin
  base := adjectives[1 + floor(random() * array_length(adjectives, 1))::int]
       || nouns[1 + floor(random() * array_length(nouns, 1))::int];
  if p_attempt > 3 then
    base := base || (floor(random() * 90 + 10))::int::text;
  end if;
  -- The table's own 3..20 length check is the contract; longest possible here
  -- is 'NorthernMeridian99' = 18.
  return left(base, 20);
end $$;

-- ----------------------------------------------------------------------------
-- 2. Repair, THEN constrain. Creating the index first would fail deployment on
--    any database that already holds a duplicate.
-- ----------------------------------------------------------------------------
do $$
declare
  v_pass    int := 0;
  v_touched int;
begin
  -- 2a. Blank / null aliases get a real generated one. `not null` means null is
  --     impossible today, but an empty string is not, and an empty string would
  --     collide with every other empty string the moment the index exists.
  loop
    v_pass := v_pass + 1;
    exit when v_pass > 25;
    update public.profiles p
       set public_alias = private.random_alias(v_pass),
           updated_at   = now()
     where btrim(coalesce(p.public_alias, '')) = '';
    exit when not exists (
      select 1 from public.profiles where btrim(coalesce(public_alias, '')) = ''
    );
  end loop;

  -- 2b. Case-insensitive duplicates. The row that has held the name longest
  --     keeps it — oldest `created_at`, then lowest id as a stable tiebreak —
  --     and every later claimant is suffixed. Repeated until clean, because a
  --     suffix can itself land on an existing name.
  v_pass := 0;
  loop
    v_pass := v_pass + 1;
    exit when v_pass > 25;

    with ranked as (
      select id,
             public_alias,
             row_number() over (
               partition by lower(btrim(public_alias))
               order by created_at asc nulls last, id asc
             ) as rn
        from public.profiles
    )
    update public.profiles p
       set public_alias = left(btrim(r.public_alias), 17)
                          || lpad(((r.rn - 1) % 100)::text, 2, '0'),
           updated_at   = now()
      from ranked r
     where p.id = r.id
       and r.rn > 1;

    get diagnostics v_touched = row_count;
    exit when v_touched = 0;
  end loop;

  -- 2c. Anything still colliding after 25 passes is pathological. Fall back to
  --     a deterministic per-account name rather than leaving the index
  --     uncreatable — the id is already public within the Online system.
  update public.profiles p
     set public_alias = 'Pilot' || substr(replace(p.id::text, '-', ''), 1, 10),
         updated_at   = now()
   where exists (
     select 1 from public.profiles q
      where q.id <> p.id
        and lower(btrim(q.public_alias)) = lower(btrim(p.public_alias))
   );
end $$;

-- ----------------------------------------------------------------------------
-- 3. The guarantee itself. Normalised on BOTH axes the app cares about:
--    surrounding whitespace and case. 'Alex', ' alex ' and 'ALEX' are one name.
--    Display casing is untouched — only the comparison is normalised.
-- ----------------------------------------------------------------------------
create unique index if not exists profiles_public_alias_key_uidx
  on public.profiles (lower(btrim(public_alias)));

-- ----------------------------------------------------------------------------
-- 4. private.ensure_profile — collision-safe.
--
--    This function is called defensively by create_private_room,
--    join_room_by_token, publish_flight_session and others. Before the index it
--    could not fail; with the index, the 9,000-value random default could
--    collide and take every one of those callers down with it. It now retries,
--    and ends on a deterministic name rather than an exception.
-- ----------------------------------------------------------------------------
create or replace function private.ensure_profile(p_uid uuid)
returns void language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_alias text;
begin
  if p_uid is null then return; end if;
  if exists (select 1 from public.profiles where id = p_uid) then return; end if;

  for i in 1..12 loop
    v_alias := private.random_alias(i);
    begin
      insert into public.profiles (id, public_alias)
        values (p_uid, v_alias)
        on conflict (id) do nothing;
      return;
    exception when unique_violation then
      -- The alias was taken between generating and inserting. Try another.
      null;
    end;
  end loop;

  insert into public.profiles (id, public_alias)
    values (p_uid, 'Pilot' || substr(replace(p_uid::text, '-', ''), 1, 10))
    on conflict (id) do nothing;
end $$;

-- ----------------------------------------------------------------------------
-- 5. public.claim_public_alias — the ONLY way an alias changes.
--
--    One UPDATE. It either takes the name or the index refuses it; there is no
--    window between deciding and writing. Returns a shaped result rather than
--    raising, so "taken" is an answer the app can render inline instead of an
--    error it has to interpret.
--
--    Re-casing your own name is not a conflict with yourself: that case is
--    detected before the update and always succeeds.
-- ----------------------------------------------------------------------------
create or replace function public.claim_public_alias(p_alias text)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid   uuid := auth.uid();
  v_raw text := btrim(coalesce(p_alias, ''));
  v_key text := lower(btrim(coalesce(p_alias, '')));
  prof  public.profiles;
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  if char_length(v_raw) < 3 or char_length(v_raw) > 20 then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  perform private.ensure_profile(uid);
  select * into prof from public.profiles where id = uid;
  if prof.id is null then raise exception 'profile_unavailable'; end if;

  -- Same name, different spelling — the caller already owns this key.
  if lower(btrim(prof.public_alias)) = v_key then
    update public.profiles
       set public_alias = v_raw, updated_at = now()
     where id = uid;
    select * into prof from public.profiles where id = uid;
    return jsonb_build_object('ok', true, 'profile', to_jsonb(prof));
  end if;

  begin
    update public.profiles
       set public_alias = v_raw, updated_at = now()
     where id = uid;
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'taken');
  end;

  select * into prof from public.profiles where id = uid;
  return jsonb_build_object('ok', true, 'profile', to_jsonb(prof));
end $$;

revoke all on function public.claim_public_alias(text) from public;
grant execute on function public.claim_public_alias(text) to authenticated;

-- ----------------------------------------------------------------------------
-- 6. public.ensure_unique_alias — repair for an authenticated profile whose
--    alias is somehow blank. Belt and braces: `not null` plus the repair above
--    should make this unreachable, but "the public name always exists" is a
--    guarantee worth being able to restate on demand.
-- ----------------------------------------------------------------------------
create or replace function public.ensure_unique_alias()
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid  uuid := auth.uid();
  prof public.profiles;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform private.ensure_profile(uid);
  select * into prof from public.profiles where id = uid;
  if prof.id is null then raise exception 'profile_unavailable'; end if;

  if btrim(coalesce(prof.public_alias, '')) = '' then
    for i in 1..12 loop
      begin
        update public.profiles
           set public_alias = private.random_alias(i), updated_at = now()
         where id = uid;
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;
    select * into prof from public.profiles where id = uid;
  end if;

  return to_jsonb(prof);
end $$;

revoke all on function public.ensure_unique_alias() from public;
grant execute on function public.ensure_unique_alias() to authenticated;
