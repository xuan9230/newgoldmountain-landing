-- New Gold Mountain — signup table.
-- Idempotent: safe to re-run.
--
--   psql "$DATABASE_URL" -f supabase/schema.sql
-- or paste into the Supabase dashboard SQL Editor.

create table if not exists public.members (
  id         uuid primary key default gen_random_uuid(),
  name       text        not null,
  email      text        not null,
  bio        text,
  created_at timestamptz not null default now()
);

-- LinkedIn profile. The form requires it — salons are invite-only, so a
-- profile is how a signup gets vetted. Nullable in the database on purpose:
-- the two people who joined before this field existed genuinely have none
-- recorded, and backfilling a placeholder would be worse than a null.
alter table public.members add column if not exists linkedin text;

-- Case-insensitive uniqueness: Stan@x.com and stan@x.com are the same person.
-- A duplicate signup surfaces as HTTP 409, which join.html treats as success.
create unique index if not exists members_email_lower_idx
  on public.members (lower(email));

-- Length and shape limits mirror join.html's own validation. The endpoint is
-- public, so the database enforces them rather than trusting the client.
-- Dropped and recreated so this block stays re-runnable as limits change.
alter table public.members drop constraint if exists members_name_len;
alter table public.members drop constraint if exists members_email_len;
alter table public.members drop constraint if exists members_bio_len;
alter table public.members drop constraint if exists members_linkedin_shape;

alter table public.members
  add constraint members_name_len
    check (char_length(name) between 1 and 80),
  add constraint members_email_len
    check (char_length(email) between 3 and 160),
  -- bio was optional and capped at 500; it is now required by the form and
  -- meant to carry enough for a human to judge fit, hence the bigger ceiling.
  add constraint members_bio_len
    check (bio is null or char_length(bio) between 1 and 2000),
  -- join.html normalises whatever is pasted to this canonical form, so the
  -- stored value is always directly clickable.
  add constraint members_linkedin_shape
    check (linkedin is null
           or linkedin ~ '^https://www\.linkedin\.com/in/[A-Za-z0-9%._~-]{1,100}$');

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- The publishable key ships in join.html, so anyone can read it out of the
-- page source. It maps to the `anon` role, which gets INSERT and nothing else:
-- no select, no update, no delete. Signups go in; the member list never comes
-- back out. Reading the list requires the dashboard or the secret key.
-- ---------------------------------------------------------------------------
alter table public.members enable row level security;

-- Supabase grants `authenticated` full table privileges by default. RLS already
-- blocks them (no policy targets that role), but this project has no login at
-- all, so drop the privileges too rather than leave them for a future foot-gun.
revoke all on table public.members from anon, authenticated;
grant insert on table public.members to anon;

drop policy if exists "anyone can join" on public.members;
create policy "anyone can join"
  on public.members
  for insert
  to anon
  with check (true);

-- ---------------------------------------------------------------------------
-- Heartbeat
--
-- Supabase pauses free projects after 7 days without database activity, which
-- would silently break the signup form. api/keepalive.mjs calls this daily.
--
-- It records every ping in a singleton row, so "is the cron actually firing?"
-- is answerable after the fact:
--
--   select * from public.heartbeat;
--
-- A write (not just a read) is deliberate: it is unambiguous database
-- activity, and it leaves the audit trail.
--
-- SECURITY DEFINER so the anon role can run it without holding any table
-- privileges of its own; search_path is pinned per Postgres guidance.
-- ---------------------------------------------------------------------------
create table if not exists public.heartbeat (
  id         int primary key default 1,
  last_ping  timestamptz not null default now(),
  ping_count bigint      not null default 0,
  constraint heartbeat_singleton check (id = 1)
);

insert into public.heartbeat (id) values (1) on conflict (id) do nothing;

alter table public.heartbeat enable row level security;
revoke all on table public.heartbeat from anon, authenticated;

create or replace function public.heartbeat()
  returns timestamptz
  language plpgsql
  security definer
  set search_path = public, pg_temp
as $$
declare
  t timestamptz;
begin
  update public.heartbeat
     set last_ping = now(), ping_count = ping_count + 1
   where id = 1
  returning last_ping into t;
  return t;
end
$$;

revoke all on function public.heartbeat() from public;
grant execute on function public.heartbeat() to anon;
