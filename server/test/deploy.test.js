// Keeps render.yaml (story C5) in step with the server it deploys.
const fs = require('fs');
const path = require('path');
const request = require('supertest');
const app = require('../src/index');
const pkg = require('../package.json');

// Git on Windows checks files out with CRLF line endings; compare as LF everywhere.
const blueprint = fs.readFileSync(path.join(__dirname, '..', '..', 'render.yaml'), 'utf8').replace(/\r\n/g, '\n');
const setting = (key) => {
  const match = blueprint.match(new RegExp(`^\\s+${key}: (.+)$`, 'm'));
  if (!match) throw new Error(`render.yaml has no ${key}`);
  return match[1].trim().replace(/^"|"$/g, '');
};

test('deploys the server folder on the free plan', () => {
  expect(setting('rootDir')).toBe('server');
  expect(setting('plan')).toBe('free');
});

test('health check path is a working endpoint', async () => {
  const res = await request(app).get(setting('healthCheckPath'));
  expect(res.status).toBe(200);
  expect(res.body).toEqual({ status: 'ok' });
});

test('start command runs the real server entry point', () => {
  expect(setting('startCommand')).toBe('npm start');
  expect(pkg.scripts.start).toBe('node src/index.js');
});

test('build installs from the lockfile without dev dependencies', () => {
  expect(setting('buildCommand')).toBe('npm ci --omit=dev');
  expect(fs.existsSync(path.join(__dirname, '..', 'package-lock.json'))).toBe(true);
  // The server must not need a dev dependency at runtime.
  for (const dep of Object.keys(pkg.devDependencies)) {
    for (const file of ['index.js', 'routes/forecast.js', 'lib/weather.js', 'lib/outfit.js']) {
      const code = fs.readFileSync(path.join(__dirname, '..', 'src', file), 'utf8');
      expect([file, code.includes(`require('${dep}')`)]).toEqual([file, false]);
    }
  }
});

test('Node version matches package.json engines', () => {
  const match = blueprint.match(/- key: NODE_VERSION\s+value: "(\d+)"/);
  expect(match).not.toBeNull();
  const major = Number(match[1]);
  expect(major).toBeGreaterThanOrEqual(Number(pkg.engines.node.match(/\d+/)[0]));
});

test('every env var set in render.yaml is one the server reads', () => {
  const keys = [...blueprint.matchAll(/- key: (\w+)/g)].map((m) => m[1]).filter((k) => k !== 'NODE_VERSION');
  const src = ['index.js', 'lib/weather.js'].map((f) => fs.readFileSync(path.join(__dirname, '..', 'src', f), 'utf8')).join('\n');
  for (const key of keys) expect(src).toContain(`process.env.${key}`);
});
