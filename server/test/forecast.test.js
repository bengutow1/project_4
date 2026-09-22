const request = require('supertest');
const app = require('../src/index');

describe('GET /api/forecast', () => {
  test('rejects request with no city or coordinates', async () => {
    const res = await request(app).get('/api/forecast');
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  test('returns weather and outfit for valid coordinates', async () => {
    const res = await request(app).get('/api/forecast').query({ lat: 30.4515, lon: -91.1871 });
    expect(res.status).toBe(200);
    expect(res.body.weather).toBeDefined();
    expect(res.body.outfit.items.length).toBeGreaterThan(0);
  }, 15000);
});

describe('GET /health', () => {
  test('returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
