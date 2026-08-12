// Supabase pauses free-tier projects after 7 days with no database activity.
// A paused project means the join form silently stops working — so this runs
// daily (see vercel.json) and touches the database to keep it awake.
//
// Env vars required in Vercel (Project → Settings → Environment Variables):
//   SUPABASE_URL          e.g. https://xxxx.supabase.co
//   SUPABASE_SERVICE_KEY  the service_role key — server-side only, never in the browser
//
// Optional: set CRON_SECRET and Vercel will send it as a Bearer token,
// so only Vercel's scheduler can trigger this.

export default async function handler(req, res) {
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.authorization !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;

  if (!url || !key) {
    return res.status(500).json({ error: 'SUPABASE_URL or SUPABASE_SERVICE_KEY is not set' });
  }

  try {
    // cheapest possible query that still reaches Postgres
    const r = await fetch(`${url}/rest/v1/members?select=id&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` }
    });

    if (!r.ok) throw new Error(`Supabase responded ${r.status}`);

    return res.status(200).json({ ok: true, pinged: new Date().toISOString() });
  } catch (err) {
    console.error('[keepalive]', err);
    return res.status(500).json({ error: String(err) });
  }
}
