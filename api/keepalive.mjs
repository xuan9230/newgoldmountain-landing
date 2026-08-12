// Supabase pauses free-tier projects after 7 days with no database activity.
// A paused project means the join form silently stops working — so this runs
// daily (see vercel.json) and calls public.heartbeat(), which executes a real
// query in Postgres without touching any data.
//
// Env vars in Vercel (Project → Settings → Environment Variables):
//   SUPABASE_URL              e.g. https://wzmnyrlpjdlkdpidicmg.supabase.co
//   SUPABASE_PUBLISHABLE_KEY  the sb_publishable_... key
//
// Neither is secret — the same values already ship inside join.html. No
// service/secret key is needed anywhere in the deployment.
//
// Optional: set CRON_SECRET and Vercel sends it as a Bearer token, so only
// Vercel's scheduler can trigger this endpoint.

export default async function handler(req, res) {
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.authorization !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) {
    return res
      .status(500)
      .json({ error: 'SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is not set' });
  }

  try {
    const r = await fetch(`${url}/rest/v1/rpc/heartbeat`, {
      method: 'POST',
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json'
      },
      body: '{}'
    });

    if (!r.ok) throw new Error(`Supabase responded ${r.status}`);

    const dbTime = await r.json();
    return res.status(200).json({ ok: true, dbTime });
  } catch (err) {
    console.error('[keepalive]', err);
    return res.status(500).json({ error: String(err) });
  }
}
