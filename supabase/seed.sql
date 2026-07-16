-- FocusGlobe Online — seed data.
-- Intentionally empty for production: every profile is created by the
-- `on_auth_user_created` trigger when a real user signs in with Apple, and no
-- fake pilots/friends/rooms may exist in the backend (decorative bots live
-- client-side only and never touch Supabase).
--
-- For local development with `supabase start`, you may create test auth users
-- via the Studio Auth panel; their profiles appear automatically.
select 1;
