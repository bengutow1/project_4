# Weather + Outfit Suggester — Server

Node.js/Express server for the Weather + Outfit Suggester app. It fetches
live weather from the free [Open-Meteo](https://open-meteo.com/) API (no API
key needed) and adds rule-based outfit recommendations on top.

## Run locally

Requires Node.js 18 or newer.

```bash
cd server
npm install
npm start        # http://localhost:3000
```

`npm run dev` does the same but restarts when you save a file.

| Environment variable | Default | Purpose |
| -------------------- | ------- | ------- |
| `PORT` | `3000` | Port the server listens on. |
| `UPSTREAM_TIMEOUT_MS` | `8000` | How long to wait for Open-Meteo before returning a 504. |

## Endpoints

| Method | Path | Purpose |
| ------ | ---- | ------- |
| GET | `/api/forecast` | Current weather and an outfit for a city or coordinates. |
| GET | `/health` | Liveness check for CI and hosting. |

All responses are JSON, including errors. CORS is open to any origin, so the
Flutter web build can call the server directly. Any other path or method
returns a 404 with an `error` message.

## `GET /api/forecast`

### Query parameters

Send **either** `city` **or** both `lat` and `lon`. If both are sent, the coordinates win.

| Parameter | Type | Rules |
| --------- | ---- | ----- |
| `city` | string | 1–100 characters after trimming, sent once. Can include a state or country: `Paris, TX`. See [City names](#city-names). |
| `lat` | number | −90 to 90. Requires `lon`. |
| `lon` | number | −180 to 180. Requires `lat`. |

Remember to URL-encode the city (`Baton%20Rouge`, `Paris%2C%20TX`).

### Examples

```bash
curl "http://localhost:3000/api/forecast?city=Baton%20Rouge"
curl "http://localhost:3000/api/forecast?city=Springfield%2C%20IL"
curl "http://localhost:3000/api/forecast?lat=30.45&lon=-91.18"
```

```js
const res = await fetch(`${BASE_URL}/api/forecast?city=${encodeURIComponent('Paris, TX')}`);
const body = await res.json();
if (!res.ok) showError(body.error); // every error has an `error` string
```

### Successful response (200)

```json
{
  "location": { "name": "Baton Rouge", "region": "Louisiana", "country": "United States", "lat": 30.45075, "lon": -91.15455 },
  "weather": {
    "tempF": 52, "condition": "Moderate rain", "highF": 58, "lowF": 47,
    "precipitationProbability": 80, "windMph": 12, "isDay": true, "uvIndex": 1,
    "time": "2026-10-01T09:45"
  },
  "outfit": {
    "summary": "52°F and rainy → rain jacket, long-sleeve shirt, long pants, umbrella",
    "items": [
      { "label": "rain jacket", "category": "outerwear", "warmth": "light", "waterproof": true },
      { "label": "long-sleeve shirt", "category": "top", "warmth": "light", "waterproof": false },
      { "label": "long pants", "category": "bottom", "warmth": "light", "waterproof": false },
      { "label": "umbrella", "category": "accessory", "warmth": "none", "waterproof": true }
    ]
  }
}
```

### Response fields

Fields marked "or null" are always present but may be `null`; every other field is always a value of the stated type.

| Field | Type | Meaning |
| ----- | ---- | ------- |
| `location.name` | string or null | Place name for `city` requests; `null` for `lat`/`lon` requests (show "Current location"). |
| `location.region` | string or null | State or region, e.g. `Texas`; `null` for `lat`/`lon` requests or when Open-Meteo has none. |
| `location.country` | string or null | Country name; `null` for `lat`/`lon` requests. |
| `location.lat` | number | Latitude used for the forecast. |
| `location.lon` | number | Longitude used for the forecast. |
| `weather.tempF` | number | Current temperature, °F. |
| `weather.condition` | string | Plain-English sky condition from the WMO weather code, or `Condition unavailable`. |
| `weather.highF` | number or null | Today's high at the location, °F. |
| `weather.lowF` | number or null | Today's low at the location, °F. |
| `weather.precipitationProbability` | number | Chance of precipitation, 0–100 (%). `0` if Open-Meteo has no value. |
| `weather.windMph` | number | Wind speed at 10 m, mph. `0` if Open-Meteo has no value. |
| `weather.isDay` | boolean | Whether it is currently daytime at the location. |
| `weather.uvIndex` | number or null | Current UV index. |
| `weather.time` | string or null | Time of the reading in the location's own timezone, `YYYY-MM-DDTHH:MM`. |
| `outfit.summary` | string | One-line text suggestion, e.g. for a plain-text card. |
| `outfit.items` | array | Outfit items; see [Outfit items](#outfit-items-and-the-closet-matching-contract). |
| `outfit.items[].label` | string | Display name, e.g. `rain jacket`. |
| `outfit.items[].category` | string | `outerwear`, `top`, `bottom` or `accessory`. |
| `outfit.items[].warmth` | string | `none`, `light`, `medium` or `heavy`. |
| `outfit.items[].waterproof` | boolean | Whether the item is meant for rain. |

Units are fixed at °F and mph.

### Errors

Every error response looks like `{ "error": "<message you can show the user>" }`.
A 422 also includes `candidates`.

| Status | When | Example `error` |
| ------ | ---- | --------------- |
| 400 | Neither `city` nor `lat`/`lon` given | `Provide either "city" or "lat" and "lon" query params.` |
| 400 | Only one of `lat`/`lon` given | `Provide both "lat" and "lon", or use "city" instead.` |
| 400 | `lat` not a number in −90..90, or `lon` not in −180..180 | `"lat" must be a number between -90 and 90.` |
| 400 | `city` empty, sent more than once, or over 100 characters | `"city" must be a non-empty string.` |
| 404 | No place has that name (may suggest close matches) | `No location found for "Londo". Did you mean London, England, United Kingdom?` |
| 404 | Unknown path or method | `Not found: POST /api/forecast. See server/README.md for the available endpoints.` |
| 422 | The name matches several similar-sized places | `"Springfield" matches several places: ... Add a state or country, e.g. "Springfield, Missouri".` |
| 502 | Open-Meteo is unreachable, returns an error, or returns bad data | `Weather service is unreachable. Please try again later.` |
| 504 | Open-Meteo takes longer than `UPSTREAM_TIMEOUT_MS` | `Weather service timed out. Please try again.` |
| 500 | Unexpected server bug (also logged to the console) | `Something went wrong on the server. Please try again.` |

A 422 lists up to five places, largest first, so a client can offer them as choices.
Each has the same shape as `location`:

```json
{
  "error": "\"Springfield\" matches several places: Springfield, Missouri, United States; Springfield, Massachusetts, United States. Add a state or country, e.g. \"Springfield, Missouri\".",
  "candidates": [
    { "name": "Springfield", "region": "Missouri", "country": "United States", "lat": 37.21533, "lon": -93.29824 },
    { "name": "Springfield", "region": "Massachusetts", "country": "United States", "lat": 42.10148, "lon": -72.58981 }
  ]
}
```

To fetch one of them, call again with `lat`/`lon`, or with `city` set to `"<name>, <region>"`.

### City names

`city` can be `Paris`, `Paris, TX`, `Paris, Texas` or `Paris, Texas, USA`. The part before
the first comma is the place name; each part after it must match the place's state or region,
country name, or country code (US state abbreviations work). Only exact name matches are
accepted, ignoring case, accents and periods (`sao paulo`, `St Louis`), so a typo returns a
404 with suggestions instead of the wrong city. When several places share the name, the
largest is used if it has at least 5× the population of the next one (`Paris` → Paris,
France); otherwise the request fails with 422.

### Outfit items and the closet-matching contract

Each `outfit.items[]` entry carries `category`, `warmth`, and `waterproof` on
top of its display `label`. The app's closet feature matches these against a
user's own tagged clothing items instead of showing generic text:

- `category`: `'outerwear' | 'top' | 'bottom' | 'accessory'`
- `warmth`: `'none' | 'light' | 'medium' | 'heavy'`
- `waterproof`: `boolean`

Tag your closet items with the same three fields and match on `category`
first, then prefer the closest `warmth` and matching `waterproof` when
`precipitationProbability` is high.

Guarantees every outfit meets (enforced by tests in `test/outfit.test.js`):

- At least one `top` and exactly one `bottom`.
- At most one `outerwear` item: always one below 60°F, never one at 75°F or above.
- When rain is likely (`precipitationProbability` ≥ 50), at least one waterproof `accessory`.
- Items are ordered outerwear, tops, bottom, accessories; labels don't repeat.

### Outfit rules

Base layers by temperature (°F):

| Temperature | Outerwear | Top(s) | Bottom | Accessories |
| ----------- | --------- | ------ | ------ | ----------- |
| below 32 | heavy winter coat (heavy) | sweater or thermal top (heavy) | lined or insulated pants (heavy) | gloves, beanie (heavy) |
| 32–44 | warm jacket (medium) | sweater (medium) | long pants (medium) | — |
| 45–59 | light jacket or hoodie (light) | long-sleeve shirt (light) | long pants (light) | — |
| 60–74 | — | t-shirt (none), light layers (light) | jeans or light pants (light) | — |
| 75 and up | — | t-shirt (none) | shorts (none) | — |

Then, in order:

1. **Rain likely (≥ 50%)**: the jacket is swapped for a waterproof one of the same
   warmth (waterproof winter coat / waterproof warm jacket / rain jacket), and an
   `umbrella` is added. The summary says "rainy", or "snowy" below 32°F.
2. **Rain possible (20–49%)**: `umbrella (just in case)` is added.
3. **Wind ≥ 20 mph from 60–74°F**: a `windbreaker` (light) is added. Colder outfits
   already have a jacket, and it's too warm for one at 75°F and up.
4. **Sun, daytime only**: `sunglasses` when `uvIndex` ≥ 3, plus a `sun hat` when
   `uvIndex` ≥ 8. If the UV index is unavailable, sunglasses are suggested at 70°F
   and up with under a 20% chance of rain.

All thresholds are constants at the top of `src/lib/outfit.js`.

## `GET /health`

Returns `{ "status": "ok" }` with status 200.

## Deploying (Render)

The server is deployed on [Render](https://render.com)'s free tier using the
Blueprint in [`render.yaml`](../render.yaml) at the repo root.

**Live URL:** `https://<your-service>.onrender.com` (replace once deployed)

### First-time setup

1. Sign in to Render with GitHub.
2. Click **New → Blueprint**, pick the `project_4` repo, and click **Apply**.
   If the repo isn't listed, the repo owner has to install Render's GitHub app
   on their account with access to `project_4`.
3. Wait for the first deploy to say **Live**, then copy the service URL.

Render then redeploys automatically whenever `server/` changes on `master`.
All settings (Node version, build and start commands, health check, environment
variables) live in `render.yaml`, so change them there rather than in the dashboard;
`test/deploy.test.js` checks the file still matches the server.

### Checking a deploy

```bash
npm run smoke -- https://<your-service>.onrender.com
```

This calls the live server from your machine and checks `/health`, a city
forecast, a coordinates forecast, and a 400 error. It prints `All checks passed.`
when the deploy is working.

### Free tier limits

- **Sleeps when idle.** After 15 minutes with no requests the service spins down;
  the next request takes about a minute while it wakes up. The app gives up after
  20 seconds, so the first request may fail with "timed out". Tapping **Retry**
  works once the server is awake. Before a demo, open `/health` in a browser to
  wake it.
- **No saved files.** The filesystem is reset on every deploy and restart. The
  server doesn't store anything, so this is fine today.

### Pointing the app at it

```bash
flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com
flutter build apk --dart-define=API_BASE_URL=https://<your-service>.onrender.com
```

Use the URL without a trailing slash.

## Tests

```bash
npm test
```

This runs every test with coverage, which takes a few seconds. CI runs the same command on every push
that touches `server/` (`.github/workflows/server-build.yml`).

| File | What it covers |
| ---- | -------------- |
| `test/forecast.test.js` | The HTTP API end to end: parameters, response shape, every error status, CORS. |
| `test/weather.test.js` | Open-Meteo requests and parsing, and city-name resolution. |
| `test/outfit.test.js` | Every outfit rule and the closet-matching guarantees. |
| `test/docs.test.js` | This README: the example response and the field table must match what the server returns. |
| `test/deploy.test.js` | `render.yaml`: health check, start command, Node version and env vars match the server. |

Tests never call the real Open-Meteo API: `test/setup.js` makes any unmocked `fetch`
fail with a message telling you to mock it. Mock it like this:

```js
jest.spyOn(global, 'fetch').mockResolvedValueOnce({ ok: true, status: 200, json: async () => body });
```

`npm test` also fails if any line or branch of `src/lib/outfit.js` is untested.

## Project layout

```
src/index.js            Express app, /health and the JSON 404
src/routes/forecast.js  GET /api/forecast: validation and error responses
src/lib/weather.js      Open-Meteo geocoding and forecast calls
src/lib/outfit.js       Outfit rules
scripts/smoke-test.js   Checks a deployed server (npm run smoke)
../render.yaml          Render deployment settings
```

## Notes for maintainers

- **Changing the response:** update the example and the field table above in the same PR.
  `test/docs.test.js` fails if they drift from what the server returns.
- **Keep the 404 message prefix:** the Flutter app shows "City not found" when an `error`
  starts with `No location found`, so keep that prefix if you reword the message.
- **422 messages are shown as-is:** the app displays a 422 `error` directly, so keep it user-friendly.
