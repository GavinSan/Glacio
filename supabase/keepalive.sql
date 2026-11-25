-- Keep-alive for the Supabase Free plan (projects pause after ~7 days with no activity).
-- Run once in Supabase: Dashboard -> SQL Editor -> New query -> paste -> Run.
-- The function only returns 1. It reads no tables and exposes no data.
create or replace function public.glacio_ping()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$ select 1 $$;

revoke all on function public.glacio_ping() from public;
grant execute on function public.glacio_ping() to anon, authenticated;
