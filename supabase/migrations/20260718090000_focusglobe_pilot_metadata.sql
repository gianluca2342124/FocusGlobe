-- ============================================================================
-- FocusGlobe Online — pilot display metadata for the in-flight detail popover.
-- Adds two OPTIONAL, display-level fields to the canonical Global presence row:
--   • is_pro   — a plain boolean PRO badge (never a product identifier);
--   • sound_id — the pilot's journey-sound id from the app's fixed catalog
--                (a short label key, never free text shown verbatim).
-- publish_global_flight is recreated with two DEFAULTED parameters so older
-- clients calling with the previous seven named parameters keep working
-- unchanged. Idempotent; safe after all prior migrations. No RLS changes.
-- ============================================================================

alter table public.active_flights add column if not exists is_pro boolean not null default false;
alter table public.active_flights add column if not exists sound_id text;

-- Recreate (not overload) the publisher: PostgREST must resolve exactly ONE
-- function named publish_global_flight.
drop function if exists public.publish_global_flight(text, text, text, text, integer, boolean, boolean);

create or replace function public.publish_global_flight(
    p_client_session_id text,
    p_sky_id            text,
    p_balloon_skin_id   text,
    p_focus_category    text,
    p_duration_seconds  integer,
    p_is_infinite       boolean,
    p_is_paused         boolean default false,
    p_is_pro            boolean default false,
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
       is_pro, sound_id)
  values (uid, p_client_session_id, p_sky_id, coalesce(nullif(p_balloon_skin_id, ''), 'default'),
          'public', coalesce(nullif(p_focus_category, ''), 'Focus'),
          v_started, v_end,
          case when coalesce(p_is_paused, false) then clock_timestamp() else null end,
          'active', clock_timestamp(), clock_timestamp() + interval '13 hours',
          coalesce(p_is_pro, false), nullif(p_sound_id, ''))
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
         is_pro            = excluded.is_pro,
         sound_id          = excluded.sound_id
  returning * into result;

  return jsonb_build_object('server_now',        clock_timestamp(),
                            'started_at',         result.started_at,
                            'expected_end_at',    result.expected_end_at,
                            'client_session_id',  result.client_session_id);
end $$;

revoke execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, boolean, text) from public, anon;
grant  execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, boolean, text) to authenticated;
