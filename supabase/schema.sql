-- Glacio cloud storage (Supabase / Postgres)
-- Run once in Supabase: Dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- Step 1 keeps the app's data as one JSON document per user, so the phone and the
-- App Store version read exactly the same thing. Row-level security means a signed-in
-- user can only ever read or write their own row; the public (anon) key alone sees nothing.

create table if not exists public.glacio_state (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb       not null,
  version    integer     not null default 2,
  updated_at timestamptz not null default now()
);

alter table public.glacio_state enable row level security;

-- Signed-in users may use the table (row-level security below still limits them to their own row).
-- Newer Supabase projects don't grant this automatically. The public (anon) role gets nothing.
grant select, insert, update, delete on table public.glacio_state to authenticated;
revoke all on table public.glacio_state from anon;

drop policy if exists "read own state"   on public.glacio_state;
drop policy if exists "insert own state" on public.glacio_state;
drop policy if exists "update own state" on public.glacio_state;
drop policy if exists "delete own state" on public.glacio_state;

create policy "read own state"   on public.glacio_state for select to authenticated using ((select auth.uid()) = user_id);
create policy "insert own state" on public.glacio_state for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own state" on public.glacio_state for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own state" on public.glacio_state for delete to authenticated using ((select auth.uid()) = user_id);

-- Keep updated_at honest (the server's clock, not the phone's).
create or replace function public.glacio_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists glacio_touch on public.glacio_state;
create trigger glacio_touch before insert or update on public.glacio_state
  for each row execute function public.glacio_touch();
