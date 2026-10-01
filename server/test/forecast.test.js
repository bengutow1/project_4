const request = require('supertest');
const app = require('../src/index');

// All tests mock fetch so CI never depends on Open-Meteo being up.
const forecastBody = {
  current: { temperature_2m: 62, precipitation_probability: 80, wind_speed_10m: 12, is_day: 1, weather_code: 63 },
  daily: { temperature_2m_max: [68], temperature_2m_min: [54] },
};
const geocodeBody = { results: [{ latitude: 30.45, longitude: -91.18, name: 'Baton Rouge', country: 'United States' }] };

function jsonResponse(body, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

function mockFetch(...responses) {
  const spy = jest.spyOn(global, 'fetch');
  for (const r of responses) {
    if (r instanceof Error || r instanceof DOMException) spy.mockRejectedValueOnce(r);
    else spy.mockResolvedValueOnce(r);
  }
  return spy;
}

afterEach(() => jest.restoreAllMocks());

describe('GET /api/forecast — success', () => {
  test('returns weather and outfit for valid coordinates', async () => {
    mockFetch(jsonResponse(forecastBody));
    const res = await request(app).get('/api/forecast').query({ lat: 30.4515, lon: -91.1871 });
    expect(res.status).toBe(200);
    expect(res.body.location).toMatchObject({ lat: 30.4515, lon: -91.1871, name: null });
    expect(res.body.weather).toMatchObject({ tempF: 62, condition: 'Moderate rain' });
    expect(res.body.outfit.items.length).toBeGreaterThan(0);
  });

  test('returns weather and outfit for a city', async () => {
    const spy = mockFetch(jsonResponse(geocodeBody), jsonResponse(forecastBody));
    const res = await request(app).get('/api/forecast').query({ city: '  Baton Rouge  ' });
    expect(res.status).toBe(200);
    expect(res.body.location.name).toBe('Baton Rouge');
    expect(new URL(spy.mock.calls[0][0]).searchParams.get('name')).toBe('Baton Rouge');
  });

  test('accepts 0 as a valid coordinate', async () => {
    mockFetch(jsonResponse(forecastBody));
    const res = await request(app).get('/api/forecast').query({ lat: 0, lon: 0 });
    expect(res.status).toBe(200);
  });
});

describe('GET /api/forecast — input validation (400)', () => {
  test.each([
    ['nothing provided', {}, /Provide either "city" or "lat" and "lon"/],
    ['empty city', { city: '   ' }, /"city" must be a non-empty string/],
    ['city too long', { city: 'a'.repeat(101) }, /100 characters or fewer/],
    ['lat without lon', { lat: 30 }, /both "lat" and "lon"/],
    ['lon without lat', { lon: -91 }, /both "lat" and "lon"/],
    ['non-numeric lat', { lat: 'abc', lon: -91 }, /"lat" must be a number/],
    ['empty lat', { lat: '', lon: -91 }, /"lat" must be a number/],
    ['lat out of range', { lat: 91, lon: -91 }, /"lat" must be a number between -90 and 90/],
    ['lon out of range', { lat: 30, lon: -181 }, /"lon" must be a number between -180 and 180/],
  ])('%s', async (_name, query, message) => {
    const spy = jest.spyOn(global, 'fetch');
    const res = await request(app).get('/api/forecast').query(query);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(message);
    expect(spy).not.toHaveBeenCalled(); // bad input never reaches Open-Meteo
  });

  test('repeated city param is rejected', async () => {
    const res = await request(app).get('/api/forecast?city=Paris&city=Rome');
    expect(res.status).toBe(400);
  });
});

describe('GET /api/forecast — city resolution (C2)', () => {
  test('response includes region and country for a city', async () => {
    mockFetch(jsonResponse(geocodeBody), jsonResponse(forecastBody));
    const res = await request(app).get('/api/forecast').query({ city: 'Baton Rouge' });
    expect(res.body.location).toMatchObject({ name: 'Baton Rouge', country: 'United States' });
  });

  test('ambiguous city returns 422 with candidates and never fetches weather', async () => {
    const springfields = ['Missouri', 'Massachusetts', 'Illinois'].map((admin1, i) => ({
      name: 'Springfield', admin1, country: 'United States', country_code: 'US',
      latitude: 37 + i * 3, longitude: -93 + i * 10, population: 160000 - i * 20000, feature_code: 'PPLA2',
    }));
    const spy = mockFetch(jsonResponse({ results: springfields }));
    const res = await request(app).get('/api/forecast').query({ city: 'Springfield' });
    expect(res.status).toBe(422);
    expect(res.body.error).toMatch(/matches several places/);
    expect(res.body.candidates).toHaveLength(3);
    expect(res.body.candidates[1]).toMatchObject({ region: 'Massachusetts' });
    expect(spy).toHaveBeenCalledTimes(1); // no wrong-city weather lookup
  });
});

describe('GET /api/forecast — upstream failures', () => {
  test('unknown city returns 404 with a clear message', async () => {
    mockFetch(jsonResponse({}));
    const res = await request(app).get('/api/forecast').query({ city: 'Notarealplace' });
    expect(res.status).toBe(404);
    // The Flutter app relies on this prefix to show "City not found".
    expect(res.body.error).toMatch(/^No location found/);
  });

  test('Open-Meteo unreachable returns 502 with a message', async () => {
    mockFetch(new TypeError('fetch failed'));
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(502);
    expect(res.body.error).toMatch(/unreachable/);
  });

  test('Open-Meteo timeout returns 504 with a message', async () => {
    mockFetch(new DOMException('The operation was aborted due to timeout', 'TimeoutError'));
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(504);
    expect(res.body.error).toMatch(/timed out/);
  });

  test('Open-Meteo error status returns 502 with a message', async () => {
    mockFetch(jsonResponse({ reason: 'boom' }, 500));
    const res = await request(app).get('/api/forecast').query({ city: 'Baton Rouge' });
    expect(res.status).toBe(502);
    expect(res.body.error).toMatch(/Geocoding service returned an error \(500\)/);
  });

  test('Open-Meteo invalid JSON returns 502', async () => {
    mockFetch({ ok: true, status: 200, json: async () => { throw new SyntaxError('bad json'); } });
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(502);
    expect(res.body.error).toMatch(/invalid response/);
  });

  test('Open-Meteo incomplete data returns 502', async () => {
    mockFetch(jsonResponse({ current: {} }));
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(502);
    expect(res.body.error).toMatch(/incomplete data/);
  });

  test('unexpected bug returns 500 with a generic message, not a crash', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    let isolatedApp;
    jest.isolateModules(() => {
      jest.doMock('../src/lib/outfit', () => ({
        suggestOutfit: () => { throw new Error('bug'); },
      }));
      isolatedApp = require('../src/index');
    });
    mockFetch(jsonResponse(forecastBody));
    const res = await request(isolatedApp).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(500);
    expect(res.body.error).toMatch(/Something went wrong/);
    jest.dontMock('../src/lib/outfit');
  });
});

describe('API-wide behavior', () => {
  test.each([
    ['unknown path', 'get', '/api/nope', 'Not found: GET /api/nope'],
    ['wrong method', 'post', '/api/forecast', 'Not found: POST /api/forecast'],
    ['root', 'get', '/', 'Not found: GET /'],
  ])('%s returns a JSON 404', async (_name, method, url, message) => {
    const res = await request(app)[method](url);
    expect(res.status).toBe(404);
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(res.body.error).toContain(message);
  });

  test.each([
    ['success', { lat: 30, lon: -91 }, () => mockFetch(jsonResponse(forecastBody))],
    ['error', {}, () => {}],
  ])('%s responses are JSON with an open CORS header', async (_name, query, setup) => {
    setup();
    const res = await request(app).get('/api/forecast').query(query).set('Origin', 'http://localhost:5000');
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(res.headers['access-control-allow-origin']).toBe('*');
  });

  test('missing optional upstream fields come back as null or 0, never absent', async () => {
    mockFetch(jsonResponse({ current: { temperature_2m: 70 } }));
    const res = await request(app).get('/api/forecast').query({ lat: 30, lon: -91 });
    expect(res.status).toBe(200);
    expect(res.body.weather).toEqual({
      tempF: 70, condition: 'Condition unavailable', highF: null, lowF: null,
      precipitationProbability: 0, windMph: 0, isDay: false, uvIndex: null, time: null,
    });
    expect(res.body.location).toEqual({ name: null, region: null, country: null, lat: 30, lon: -91 });
  });

  test('coordinates win when both city and lat/lon are sent', async () => {
    const spy = mockFetch(jsonResponse(forecastBody));
    const res = await request(app).get('/api/forecast').query({ city: 'Paris', lat: 30, lon: -91 });
    expect(res.status).toBe(200);
    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy.mock.calls[0][0]).toContain('api.open-meteo.com/v1/forecast');
  });

  test('UPSTREAM_TIMEOUT_MS controls the Open-Meteo timeout', async () => {
    let fetchWeather;
    process.env.UPSTREAM_TIMEOUT_MS = '1234';
    jest.isolateModules(() => { ({ fetchWeather } = require('../src/lib/weather')); });
    delete process.env.UPSTREAM_TIMEOUT_MS;
    const timeout = jest.spyOn(AbortSignal, 'timeout');
    mockFetch(jsonResponse(forecastBody));
    await fetchWeather({ lat: 1, lon: 2 });
    expect(timeout).toHaveBeenCalledWith(1234);
  });
});

describe('GET /health', () => {
  test('returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
