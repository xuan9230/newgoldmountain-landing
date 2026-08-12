# New Gold Mountain 新金山

Landing page and join form for the New Gold Mountain community.

Static HTML, no build step. `index.html` is the landing page, `join.html` is the
signup form. Deployed on Vercel.

## Local preview

```bash
python3 -m http.server 4173
```

## Signup form setup (Supabase)

The join form writes to a Supabase table directly from the browser.

### 1. Create the table

Supabase dashboard → SQL Editor → run:

```sql
create table public.members (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text not null unique,
  bio        text,
  created_at timestamptz not null default now()
);

alter table public.members enable row level security;

-- anon may insert, and only insert — the member list is never readable
-- with the public key
grant insert on table public.members to anon;

create policy "anyone can join"
  on public.members
  for insert
  to anon
  with check (true);
```

### 2. Point the form at the project

In `join.html`, replace the two placeholders near the bottom:

```js
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-KEY';
```

Both come from Project Settings → API. The anon key is safe in client-side
code: the policy above grants insert only, so it cannot read the member list.

### 3. Keep the database awake

Supabase pauses free projects after 7 days without database activity, which
would break the form. `api/keepalive.js` runs daily via `vercel.json` to
prevent that. Set these in Vercel → Settings → Environment Variables:

| Variable               | Value                                         |
| ---------------------- | --------------------------------------------- |
| `SUPABASE_URL`         | `https://YOUR-PROJECT.supabase.co`            |
| `SUPABASE_SERVICE_KEY` | the `service_role` key (server-side only)     |
| `CRON_SECRET`          | any random string (optional, recommended)     |

Verify it works after deploying: `curl https://YOUR-SITE/api/keepalive`
(returns `{"ok":true,...}` when `CRON_SECRET` is unset).

## Reading signups

Supabase dashboard → Table Editor → `members`. Export to CSV from there.

## Assets

`assets/` holds the logo: `mark.svg` (primary), `mark-mono.svg`,
`mark-dark.svg`, `lockup.svg` / `lockup-dark.svg` (with wordmark), and
`favicon.svg`.
