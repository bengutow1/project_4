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
  "weather": { "tempF": 62, "condition": "Moderate rain", "highF": 68, "lowF": 54, "precipitationProbability": 80, "windMph": 12, "isDay": true },
  "outfit": {
    "summary": "62°F and rainy → light jacket or hoodie, umbrella",
    "items": [
      { "label": "light jacket or hoodie", "category": "outerwear", "warmth": "light", "waterproof": false },
      { "label": "umbrella", "category": "accessory", "warmth": "none", "waterproof": true }
    ]
  }
}
```

The forecast card displays temperature, condition, today's high/low, and wind.
For A2, units are fixed at Fahrenheit and mph; a unit toggle is deferred.
`condition` describes the current Open-Meteo WMO weather code (or
`Condition unavailable` for an unknown code). `highF` and `lowF` are for the
location's current calendar day and may be null when upstream data is missing.
The app also supports older responses that omit these three new fields,
showing unavailable labels instead of inventing values.

#### Errors

Every error response has the shape `{ "error": "<human-readable message>" }`.

| Status | When | Example message |
| ------ | ---- | --------------- |
| 400 | Neither `city` nor `lat`/`lon` given | `Provide either "city" or "lat" and "lon" query params.` |
| 400 | Only one of `lat`/`lon` given | `Provide both "lat" and "lon", or use "city" instead.` |
| 400 | `lat` not a number in -90..90, or `lon` not in -180..180 | `"lat" must be a number between -90 and 90.` |
| 400 | `city` empty, repeated, or over 100 characters | `"city" must be a non-empty string.` |
| 404 | Open-Meteo can't find the city | `No location found for "Notarealplace"` |
| 502 | Open-Meteo is unreachable, returns an error, or returns bad data | `Weather service is unreachable. Please try again later.` |
| 504 | Open-Meteo takes longer than the timeout (default 8 s) | `Weather service timed out. Please try again.` |
| 500 | Unexpected server bug (logged to the console) | `Something went wrong on the server. Please try again.` |

If both `lat`/`lon` and `city` are given, the coordinates are used.
The upstream timeout can be changed with the `UPSTREAM_TIMEOUT_MS` environment variable.

The app shows "City not found" when the error starts with `No location found`,
so keep that prefix if you change the message.

#### Closet-matching contract

Each `outfit.items[]` entry carries `category`, `warmth`, and `waterproof` on
top of its display `label`. The app's closet feature matches these against a
user's own tagged clothing items instead of showing generic text:

- `category`: `'outerwear' | 'top' | 'bottom' | 'accessory'`
- `warmth`: `'none' | 'light' | 'medium' | 'heavy'`
- `waterproof`: `boolean`

Tag your closet items with the same three fields and match on `category`
first, then prefer the closest `warmth` and matching `waterproof` when
`precipitationProbability` is high.

### `GET /health`

Returns `{ "status": "ok" }`. Used by CI/hosting health checks.

## Tests

```bash
npm test
```
