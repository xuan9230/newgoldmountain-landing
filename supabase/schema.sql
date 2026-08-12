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

-- Case-insensitive uniqueness: Stan@x.com and stan@x.com are the same person.
-- A duplicate signup surfaces as HTTP 409, which join.html treats as success.
create unique index if not exists members_email_lower_idx
  on public.members (lower(email));

-- Length limits mirror the maxlength attributes in join.html. The form is
-- public, so the database enforces them too rather than trusting the client.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'members_name_len') then
    alter table public.members
      add constraint members_name_len check (char_length(name) between 1 and 80);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'members_email_len') then
    alter table public.members
      add constraint members_email_len check (char_length(email) between 3 and 160);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'members_bio_len') then
    alter table public.members
      add constraint members_bio_len check (bio is null or char_length(bio) <= 500);
  end if;
end $$;

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
-- would silently break the signup form. api/keepalive.js calls this daily.
-- It runs a real query in Postgres but touches no data, so the publishable key
-- is enough — no secret key needs to exist anywhere in the deployment.
-- ---------------------------------------------------------------------------
create or replace function public.heartbeat()
  returns timestamptz
  language sql
  volatile
as $$ select now() $$;

grant execute on function public.heartbeat() to anon;
