# Weather + Outfit Suggester — Server

Node.js/Express server for the Weather + Outfit Suggester app. It fetches
live weather from the free [Open-Meteo](https://open-meteo.com/) API (no API
key required) and adds rule-based outfit recommendations on top.

## Run locally

```bash
cd server
npm install
npm start        # listens on http://localhost:3000
```

## API

### `GET /api/forecast`

Query params (provide one of the two):
- `city` — e.g. `?city=Baton Rouge`
- `lat` & `lon` — e.g. `?lat=30.45&lon=-91.18`

Response:
```json
{
  "location": { "name": "Baton Rouge", "lat": 30.45, "lon": -91.18 },
  "weather": { "tempF": 62, "precipitationProbability": 80, "windMph": 12, "isDay": true },
  "outfit": { "summary": "62°F and rainy → light jacket or hoodie, umbrella", "items": ["light jacket or hoodie", "umbrella"] }
}
```

### `GET /health`

Returns `{ "status": "ok" }`. Used by CI/hosting health checks.

## Tests

```bash
npm test
```
