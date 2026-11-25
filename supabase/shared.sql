-- Glacio · shared Split groups (phase 2)
-- Run once in Supabase: Dashboard -> SQL Editor -> New query -> paste -> Run. Safe to run again.
--
-- What it adds
--   profiles       one row per signed-in person (email + display name)
--   groups         a Split group
--   group_members  people in a group: signed-in users, email invites, or name-only people
--   expenses       shared costs
--   payments       "I paid you": pending until the person who got the money confirms
--   notifications  the in-app inbox (reminders, payments, invites)
-- Row-level security: you only ever see groups you belong to (or were invited to by email),
-- and only your own notifications.

create extension if not exists pgcrypto;

-- ---------- tables ----------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  name       text check (name is null or char_length(name) between 1 and 40),
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 40),
  icon       text not null default 'users' check (char_length(icon) <= 30),
  repeat     boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  user_id    uuid references auth.users (id) on delete set null,
  email      text check (email is null or char_length(email) <= 254),
  name       text not null check (char_length(name) between 1 and 40),
  added_by   uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (group_id, user_id)
);
create index if not exists group_members_user  on public.group_members (user_id);
create index if not exists group_members_email on public.group_members (lower(email));
create index if not exists group_members_group on public.group_members (group_id);

create table if not exists public.expenses (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  label      text not null check (char_length(label) between 1 and 60),
  amount     numeric(12,2) not null check (amount > 0),
  payer      uuid not null references public.group_members (id) on delete cascade,
  among      uuid[] not null check (cardinality(among) between 1 and 50),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists expenses_group on public.expenses (group_id);

create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  from_member  uuid not null references public.group_members (id) on delete cascade,
  to_member    uuid not null references public.group_members (id) on delete cascade,
  amount       numeric(12,2) not null check (amount > 0),
  status       text not null default 'pending' check (status in ('pending','confirmed')),
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now(),
  confirmed_at timestamptz
);
create index if not exists payments_group on public.payments (group_id);

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  actor      uuid default auth.uid(),
  group_id   uuid references public.groups (id) on delete cascade,
  kind       text not null check (kind in ('invite','reminder','paid','confirmed','declined','expense')),
  body       text not null check (char_length(body) <= 200),
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user on public.notifications (user_id, created_at desc);

-- ---------- profiles follow sign-ups ----------
create or replace function public.glacio_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end $$;
drop trigger if exists glacio_new_user on auth.users;
create trigger glacio_new_user after insert or update of email on auth.users
  for each row execute function public.glacio_new_user();
insert into public.profiles (id, email) select id, email from auth.users on conflict (id) do nothing;

-- ---------- helpers used by the policies (security definer avoids policy recursion) ----------
create or replace function public.glacio_my_email() returns text
language sql stable security definer set search_path = '' as $$
  select lower(coalesce((select auth.jwt() ->> 'email'), (select email from auth.users where id = (select auth.uid()))))
$$;
create or replace function public.glacio_is_member(gid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members where group_id = gid and user_id = (select auth.uid()))
$$;
create or replace function public.glacio_is_invited(gid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members
                 where group_id = gid and user_id is null and lower(email) = public.glacio_my_email())
$$;
create or replace function public.glacio_shares_group(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members a join public.group_members b on a.group_id = b.group_id
                 where a.user_id = (select auth.uid()) and b.user_id = uid)
$$;
create or replace function public.glacio_receiver_ok(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  -- the person who received the money, or anyone when that person has no account yet
  select exists (select 1 from public.group_members where id = mid and (user_id = (select auth.uid()) or user_id is null))
$$;

-- ---------- actions that need to cross a boundary ----------
-- Invite someone by email. If they already use Glacio they get an in-app notification.
create or replace function public.glacio_invite(gid uuid, invite_email text, invite_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare mid uuid; target uuid; gname text;
begin
  if not public.glacio_is_member(gid) then raise exception 'not a member of this group'; end if;
  invite_email := lower(trim(invite_email));
  if invite_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'that email does not look right'; end if;
  if exists (select 1 from public.group_members m left join auth.users u on u.id = m.user_id
             where m.group_id = gid and (lower(m.email) = invite_email or lower(u.email) = invite_email)) then
    raise exception 'already in this group';
  end if;
  insert into public.group_members (group_id, email, name)
    values (gid, invite_email, left(coalesce(nullif(trim(invite_name), ''), split_part(invite_email, '@', 1)), 40))
    returning id into mid;
  select id into target from auth.users where lower(email) = invite_email limit 1;
  select name into gname from public.groups where id = gid;
  if target is not null then
    insert into public.notifications (user_id, group_id, kind, body)
      values (target, gid, 'invite', left('You were invited to ' || gname, 200));
  end if;
  return mid;
end $$;

-- Accept an email invite: the row becomes yours.
create or replace function public.glacio_accept(mid uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.group_members set user_id = (select auth.uid())
   where id = mid and user_id is null and lower(email) = public.glacio_my_email();
  if not found then raise exception 'invite not found'; end if;
end $$;

-- Leave a group: your row stays (so costs and payments still add up) but is no longer linked to you.
create or replace function public.glacio_leave(gid uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.group_members set user_id = null, email = null
   where group_id = gid and user_id = (select auth.uid());
end $$;

-- ---------- row-level security ----------
alter table public.profiles      enable row level security;
alter table public.groups        enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses      enable row level security;
alter table public.payments      enable row level security;
alter table public.notifications enable row level security;

revoke all on public.profiles, public.groups, public.group_members, public.expenses, public.payments, public.notifications from anon;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.groups, public.group_members, public.expenses, public.payments, public.notifications to authenticated;

revoke all on function public.glacio_my_email(), public.glacio_is_member(uuid), public.glacio_is_invited(uuid),
  public.glacio_shares_group(uuid), public.glacio_receiver_ok(uuid), public.glacio_invite(uuid, text, text),
  public.glacio_accept(uuid), public.glacio_leave(uuid), public.glacio_new_user() from public, anon;
grant execute on function public.glacio_my_email(), public.glacio_is_member(uuid), public.glacio_is_invited(uuid),
  public.glacio_shares_group(uuid), public.glacio_receiver_ok(uuid), public.glacio_invite(uuid, text, text),
  public.glacio_accept(uuid), public.glacio_leave(uuid) to authenticated;

do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public'
           and tablename in ('profiles','groups','group_members','expenses','payments','notifications')
  loop execute format('drop policy %I on public.%I', r.policyname, r.tablename); end loop;
end $$;

create policy "see self and group mates" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.glacio_shares_group(id));
create policy "edit own profile" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "see my groups and invites" on public.groups for select to authenticated
  using (created_by = (select auth.uid()) or public.glacio_is_member(id) or public.glacio_is_invited(id));
create policy "create groups" on public.groups for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy "members edit group" on public.groups for update to authenticated
  using (public.glacio_is_member(id)) with check (public.glacio_is_member(id));
create policy "creator deletes group" on public.groups for delete to authenticated
  using (created_by = (select auth.uid()));

create policy "see members" on public.group_members for select to authenticated
  using (public.glacio_is_member(group_id) or user_id = (select auth.uid())
         or (user_id is null and lower(email) = public.glacio_my_email()));
-- members add name-only people; the group's creator adds themself first
create policy "add members" on public.group_members for insert to authenticated
  with check (
    (public.glacio_is_member(group_id) and user_id is null)
    or (user_id = (select auth.uid()) and exists (select 1 from public.groups g where g.id = group_id and g.created_by = (select auth.uid()))));
-- rename name-only people or yourself; nobody can attach another account to a row
create policy "edit members" on public.group_members for update to authenticated
  using (public.glacio_is_member(group_id) and (user_id is null or user_id = (select auth.uid())))
  with check (public.glacio_is_member(group_id) and (user_id is null or user_id = (select auth.uid())));
create policy "remove members or decline" on public.group_members for delete to authenticated
  using (public.glacio_is_member(group_id) or (user_id is null and lower(email) = public.glacio_my_email()));

create policy "members use expenses" on public.expenses for all to authenticated
  using (public.glacio_is_member(group_id)) with check (public.glacio_is_member(group_id));

create policy "members see payments" on public.payments for select to authenticated
  using (public.glacio_is_member(group_id));
create policy "record payments" on public.payments for insert to authenticated
  with check (public.glacio_is_member(group_id) and (status = 'pending' or public.glacio_receiver_ok(to_member)));
create policy "receiver confirms" on public.payments for update to authenticated
  using (public.glacio_is_member(group_id) and public.glacio_receiver_ok(to_member))
  with check (public.glacio_is_member(group_id) and public.glacio_receiver_ok(to_member));
create policy "members undo payments" on public.payments for delete to authenticated
  using (public.glacio_is_member(group_id));

create policy "read my inbox" on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy "mark my inbox read" on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "clear my inbox" on public.notifications for delete to authenticated
  using (user_id = (select auth.uid()));
create policy "notify group mates" on public.notifications for insert to authenticated
  with check (actor = (select auth.uid()) and (user_id = (select auth.uid()) or public.glacio_shares_group(user_id)));

-- Signed-in users can use the sync table too (in case the earlier grant was skipped).
grant select, insert, update, delete on table public.glacio_state to authenticated;
