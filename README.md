# New Gold Mountain 新金山

Landing page and join form for the New Gold Mountain community.

Static HTML, no build step. `index.html` is the landing page, `join.html` is the
signup form. Deployed on Vercel.

`cleanUrls` is on, so the pages are served at `/` and `/join` — the `.html`
URLs 308-redirect to those, which keeps any link shared earlier working.

## Local preview

```bash
python3 scripts/serve.py 4173
```

Stock `http.server` would 404 on `/join`, since the extensionless paths only
exist in production; `scripts/serve.py` resolves them the way Vercel does so
local and production behave the same.

## Signup form (Supabase)

`join.html` inserts straight into Supabase from the browser — no backend, no
build step. The schema lives in [`supabase/schema.sql`](supabase/schema.sql)
and is already applied to the live project.

### Security model

The publishable key sits in `join.html` in plain sight, which is fine by
design. RLS gives the `anon` role exactly two capabilities:

- `INSERT` on `members` — signups go in
- `EXECUTE` on `heartbeat()` — the cron ping

No select, update, or delete. Verified behaviour of the public key:

| Request                     | Result             |
| --------------------------- | ------------------ |
| insert a signup             | `201`              |
| read the member list        | `401` permission denied |
| duplicate email (any case)  | `409`              |
| delete a row                | `401`              |

Reading the member list requires the dashboard or the database password.

### Re-applying the schema

```bash
set -a && . ./.env && set +a
psql "$DATABASE_URL" -f supabase/schema.sql
```

It's idempotent. Note the dashboard's *direct* connection string is IPv6-only;
`DATABASE_URL` in `.env` uses the session pooler, which works over IPv4.

### Keeping the database awake

Supabase pauses free projects after 7 days without database activity, which
would silently break the form. `api/keepalive.mjs` runs daily via
`vercel.json` and calls `heartbeat()`. Set in Vercel → Settings →
Environment Variables:

| Variable                   | Value                              |
| -------------------------- | ---------------------------------- |
| `SUPABASE_URL`             | `https://wzmnyrlpjdlkdpidicmg.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | the `sb_publishable_...` key       |
| `CRON_SECRET`              | any random string (optional)       |

Check after deploying: `curl https://YOUR-SITE/api/keepalive` → `{"ok":true,...}`
(when `CRON_SECRET` is unset).

## Reading signups

Supabase dashboard → Table Editor → `members`, or:

```bash
set -a && . ./.env && set +a
psql "$DATABASE_URL" -c "select name, email, bio, created_at from members order by created_at desc;"
```

## Assets

`assets/` holds the logo: `mark.svg` (primary), `mark-mono.svg`,
`mark-dark.svg`, `lockup.svg` / `lockup-dark.svg` (with wordmark), and
`favicon.svg`.
