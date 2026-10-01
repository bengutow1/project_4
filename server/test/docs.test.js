// Keeps server/README.md honest: if the API changes and the docs don't, this fails.
const fs = require('fs');
const path = require('path');
const request = require('supertest');
const app = require('../src/index');

const README = fs.readFileSync(path.join(__dirname, '..', 'README.md'), 'utf8');

// Text of a README section, from its heading to the next heading of any level.
function section(heading) {
  const start = README.indexOf(`${heading}\n`);
  if (start === -1) throw new Error(`README is missing the "${heading}" section`);
  const rest = README.slice(start + heading.length + 1);
  const next = rest.search(/^#{1,6} /m);
  return next === -1 ? rest : rest.slice(0, next);
}

function firstJsonBlock(text) {
  const match = text.match(/```json\n([\s\S]*?)```/);
  if (!match) throw new Error('No ```json block found');
  return JSON.parse(match[1]);
}

// { a: { b: 1 }, c: [{ d: true }] } -> { 'a.b': 'number', 'c[].d': 'boolean' }
function fieldTypes(value, prefix = '', out = {}) {
  if (Array.isArray(value)) {
    out[prefix] = 'array';
    for (const element of value) fieldTypes(element, `${prefix}[]`, out);
  } else if (value !== null && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) fieldTypes(child, prefix ? `${prefix}.${key}` : key, out);
  } else {
    out[prefix] = value === null ? 'null' : typeof value;
  }
  return out;
}

const geocodeBody = {
  results: [{
    name: 'Baton Rouge', admin1: 'Louisiana', country: 'United States', country_code: 'US',
    latitude: 30.45075, longitude: -91.15455, population: 227470, feature_code: 'PPLA',
  }],
};
const forecastBody = {
  current: {
    time: '2026-10-01T09:45', temperature_2m: 52, precipitation_probability: 80,
    wind_speed_10m: 12, is_day: 1, weather_code: 63, uv_index: 1,
  },
  daily: { temperature_2m_max: [58], temperature_2m_min: [47] },
};
const ok = (body) => ({ ok: true, status: 200, json: async () => body });

async function liveCityResponse() {
  jest.spyOn(global, 'fetch').mockResolvedValueOnce(ok(geocodeBody)).mockResolvedValueOnce(ok(forecastBody));
  const res = await request(app).get('/api/forecast').query({ city: 'Baton Rouge' });
  expect(res.status).toBe(200);
  return res.body;
}

afterEach(() => jest.restoreAllMocks());

describe('README: GET /api/forecast', () => {
  test('example response has exactly the fields and types the server returns', async () => {
    const documented = firstJsonBlock(section('### Successful response (200)'));
    expect(fieldTypes(documented)).toEqual(fieldTypes(await liveCityResponse()));
  });

  test('example response matches the server for the same weather', async () => {
    const documented = firstJsonBlock(section('### Successful response (200)'));
    expect(await liveCityResponse()).toEqual(documented);
  });

  test('field table lists every response field with the right type', async () => {
    const rows = [...section('### Response fields').matchAll(/^\| `([^`]+)` \| ([^|]+) \|/gm)]
      .map(([, field, type]) => [field.replace(/\[\]\./g, '[].'), type.trim()]);
    const documented = Object.fromEntries(rows);
    const actual = fieldTypes(await liveCityResponse());

    expect(Object.keys(documented).sort()).toEqual(Object.keys(actual).sort());
    for (const [field, type] of Object.entries(actual)) {
      expect([field, documented[field].replace(/ or null$/, '')]).toEqual([field, type]);
    }
  });

  test('fields documented as "or null" are null for a lat/lon request', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValueOnce(ok({ current: { temperature_2m: 70 } }));
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    const actual = fieldTypes(res.body);
    const nullable = [...section('### Response fields').matchAll(/^\| `([^`]+)` \| [^|]* or null \|/gm)].map((m) => m[1]);
    expect(nullable.length).toBeGreaterThan(0);
    for (const field of nullable) expect([field, actual[field]]).toEqual([field, 'null']);
  });

  test('422 example has the same candidate shape as the server', async () => {
    const example = firstJsonBlock(section('### Errors'));
    const springfields = ['Missouri', 'Massachusetts'].map((admin1, i) => ({
      name: 'Springfield', admin1, country: 'United States', country_code: 'US',
      latitude: 37 + i * 5, longitude: -93 + i * 20, population: 169176 - i * 13247, feature_code: 'PPLA2',
    }));
    jest.spyOn(global, 'fetch').mockResolvedValueOnce(ok({ results: springfields }));
    const res = await request(app).get('/api/forecast').query({ city: 'Springfield' });
    expect(res.status).toBe(422);
    expect(fieldTypes(example)).toEqual(fieldTypes(res.body));
    expect(Object.keys(res.body.candidates[0])).toEqual(['name', 'region', 'country', 'lat', 'lon']);
  });
});

describe('README: running the server', () => {
  test('every environment variable the server reads is documented', () => {
    const srcDir = path.join(__dirname, '..', 'src');
    const files = fs.readdirSync(srcDir, { recursive: true }).filter((f) => f.endsWith('.js'));
    const used = new Set();
    for (const file of files) {
      const code = fs.readFileSync(path.join(srcDir, file), 'utf8');
      for (const [, name] of code.matchAll(/process\.env\.([A-Z0-9_]+)/g)) used.add(name);
    }
    expect(used.size).toBeGreaterThan(0);
    for (const name of used) expect(README).toContain(`| \`${name}\` |`);
  });

  test('health example matches the server', async () => {
    const res = await request(app).get('/health');
    expect(README).toContain(`Returns \`${JSON.stringify(res.body).replace(/:/g, ': ').replace(/^\{/, '{ ').replace(/\}$/, ' }')}\``);
  });
});
