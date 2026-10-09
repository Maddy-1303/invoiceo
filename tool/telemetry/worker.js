// Invoiceo usage counter — a Cloudflare Worker with a D1 database bound as DB.
// Paste this file into the Worker's code editor and deploy.
//
//   POST /v1/ping   {"id": "<install id>", "event": "install" | "active" | "first_invoice",
//                    "version": "1.0.3", "os": "windows" | "macos" | "linux" | "other"}
//                   Stores the event (once per install for install / first_invoice,
//                   once per install per day for active). Never stores IP addresses.
//   GET  /v1/stats?key=<STATS_KEY>
//                   Totals as JSON. Needs a secret named STATS_KEY on the Worker.

const EVENTS = new Set(['install', 'active', 'first_invoice']);
const ONCE = new Set(['install', 'first_invoice']);
const OSES = new Set(['windows', 'macos', 'linux', 'other']);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/v1/ping' && request.method === 'POST') return ping(request, env);
    if (url.pathname === '/v1/stats' && request.method === 'GET') return stats(url, env);
    return new Response('Not found', { status: 404 });
  },
};

async function ping(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return new Response('Bad request', { status: 400 });
  }
  const id = String(body.id || '');
  const event = String(body.event || '');
  const version = String(body.version || '');
  const os = OSES.has(body.os) ? body.os : 'other';
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(id) || !EVENTS.has(event) || !/^\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(version)) {
    return new Response('Bad request', { status: 400 });
  }
  const day = new Date().toISOString().slice(0, 10);
  if (ONCE.has(event)) {
    await env.DB.prepare(
      `INSERT INTO events (install_id, event, day, version, os)
       SELECT ?1, ?2, ?3, ?4, ?5
       WHERE NOT EXISTS (SELECT 1 FROM events WHERE install_id = ?1 AND event = ?2)`
    ).bind(id, event, day, version, os).run();
  } else {
    await env.DB.prepare(
      'INSERT OR IGNORE INTO events (install_id, event, day, version, os) VALUES (?1, ?2, ?3, ?4, ?5)'
    ).bind(id, event, day, version, os).run();
  }
  return new Response(null, { status: 204 });
}

async function stats(url, env) {
  if (!env.STATS_KEY || url.searchParams.get('key') !== env.STATS_KEY) {
    return new Response('Not found', { status: 404 });
  }
  const one = (sql, ...args) => env.DB.prepare(sql).bind(...args).first('n');
  const all = async (sql) => (await env.DB.prepare(sql).all()).results;
  const active = (days) => one(
    `SELECT COUNT(DISTINCT install_id) AS n FROM events
     WHERE event = 'active' AND day >= date('now', ?1)`, `-${days - 1} days`);
  const data = {
    installs: await one(`SELECT COUNT(*) AS n FROM events WHERE event = 'install'`),
    first_invoices: await one(`SELECT COUNT(*) AS n FROM events WHERE event = 'first_invoice'`),
    active_today: await active(1),
    active_7_days: await active(7),
    active_30_days: await active(30),
    installs_by_day: await all(
      `SELECT day, COUNT(*) AS installs FROM events WHERE event = 'install'
       GROUP BY day ORDER BY day DESC LIMIT 60`),
    first_invoices_by_day: await all(
      `SELECT day, COUNT(*) AS first_invoices FROM events WHERE event = 'first_invoice'
       GROUP BY day ORDER BY day DESC LIMIT 60`),
    installs_by_os: await all(
      `SELECT os, COUNT(*) AS installs FROM events WHERE event = 'install' GROUP BY os ORDER BY installs DESC`),
    active_7_days_by_version: await all(
      `SELECT version, COUNT(DISTINCT install_id) AS installs FROM events
       WHERE event = 'active' AND day >= date('now', '-6 days') GROUP BY version ORDER BY version DESC`),
  };
  return new Response(JSON.stringify(data, null, 2), {
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}
