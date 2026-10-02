#!/usr/bin/env node
// Checks a deployed server from the public internet (story C5).
// Usage: npm run smoke -- https://your-service.onrender.com
// A Render free service that has been idle can take about a minute to wake up,
// so the first request waits up to 90 seconds.

const base = (process.argv[2] || process.env.SERVER_URL || '').replace(/\/+$/, '');
if (!/^https?:\/\//.test(base)) {
  console.error('Usage: npm run smoke -- https://your-service.onrender.com');
  process.exit(2);
}

async function get(path, timeoutMs) {
  const started = Date.now();
  const res = await fetch(`${base}${path}`, { signal: AbortSignal.timeout(timeoutMs) });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    throw new Error(`${path} returned non-JSON (status ${res.status}): ${text.slice(0, 120)}`);
  }
  return { status: res.status, body, ms: Date.now() - started };
}

const checks = [
  ['GET /health returns { "status": "ok" }', async () => {
    const r = await get('/health', 90000);
    if (r.status !== 200 || r.body.status !== 'ok') throw new Error(`got ${r.status} ${JSON.stringify(r.body)}`);
    return `${r.ms} ms`;
  }],
  ['GET /api/forecast?city=Baton Rouge returns real data', async () => {
    const r = await get('/api/forecast?city=Baton%20Rouge', 30000);
    if (r.status !== 200) throw new Error(`got ${r.status}: ${r.body.error}`);
    const { location, weather, outfit } = r.body;
    if (location.name !== 'Baton Rouge' || typeof weather.tempF !== 'number' || !outfit.items.length) {
      throw new Error(`unexpected body ${JSON.stringify(r.body).slice(0, 200)}`);
    }
    return `${weather.tempF}°F, ${weather.condition}, reading from ${weather.time}`;
  }],
  ['GET /api/forecast?lat=30.45&lon=-91.18 returns real data', async () => {
    const r = await get('/api/forecast?lat=30.45&lon=-91.18', 30000);
    if (r.status !== 200) throw new Error(`got ${r.status}: ${r.body.error}`);
    if (typeof r.body.weather.tempF !== 'number') throw new Error(`unexpected body ${JSON.stringify(r.body).slice(0, 200)}`);
    return r.body.outfit.summary;
  }],
  ['Bad input returns a JSON 400', async () => {
    const r = await get('/api/forecast', 30000);
    if (r.status !== 400 || !r.body.error) throw new Error(`got ${r.status}`);
    return r.body.error;
  }],
];

(async () => {
  console.log(`Smoke-testing ${base}\n`);
  let failed = 0;
  for (const [name, run] of checks) {
    try {
      console.log(`  PASS  ${name}\n        ${await run()}`);
    } catch (err) {
      failed += 1;
      const why = err.name === 'TimeoutError' ? 'timed out' : err.message;
      console.log(`  FAIL  ${name}\n        ${why}`);
    }
  }
  console.log(failed ? `\n${failed} check(s) failed.` : '\nAll checks passed.');
  process.exit(failed ? 1 : 0);
})();
