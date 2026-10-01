# Weather + Outfit Suggester

A Flutter app that fetches live weather from the free [Open-Meteo](https://open-meteo.com/)
API (no API key needed) and layers on its own recommendation logic — e.g.
"62°F and rain → jacket and umbrella." The app displays the forecast and the
recommendation; the server is where the real value is added.

Core feature: a personal **closet**. Users photograph or upload their own
clothing (camera or gallery), tag each item (category, warmth, waterproof),
and the app matches those real items to the day's weather instead of just
showing generic text — with a visual "what to wear" screen.

## Project structure

```
lib/       Flutter app source
server/    Node.js + Express API (weather fetch + outfit logic)
TASKS.md   Full task list (20 user stories / 4 independent tracks)
```

## Running the app

```bash
flutter pub get
flutter run
```

### Location search (A1)

The home screen starts empty with `e.g. Baton Rouge` as a hint. Nothing is
fetched and no permission is requested on launch. **Get Weather** (or the
keyboard search action) searches the entered city. **Use my location** requests
foreground location access and fetches weather using coordinates. Denied or
blocked permission, disabled services, and GPS failures leave manual city
search available. Unknown cities show an error and can be corrected and retried.

Start the server first. The API defaults to `http://localhost:3000`.
For the Android emulator, use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For a physical device, set `API_BASE_URL` to a reachable server address.
Android debug builds allow local HTTP; use an HTTPS server for release builds
and Apple devices. Browser GPS requires localhost or HTTPS.

### Live API configuration (A5)

The base URL is a compile-time Dart constant in `WeatherService`, configured
with `--dart-define=API_BASE_URL=...`; no `.env` loader or build flavors are needed.
It defaults to `http://localhost:3000` for local web/desktop development.
Use your computer's LAN address for a physical Android device during development.
Supply the server origin (optionally including a hosting path prefix), without
`/api/forecast`, query parameters, or fragments. Trailing slashes are supported.

```bash
# Deployed server (replace with your actual HTTPS host)
flutter run --dart-define=API_BASE_URL=https://your-server.example.com
flutter build apk --release --dart-define=API_BASE_URL=https://your-server.example.com
flutter build web --dart-define=API_BASE_URL=https://your-server.example.com
```

Changing environments requires restarting/rebuilding with the new define, with
no source changes. This URL is public configuration, not a place for secrets.
An HTTPS web app also needs an HTTPS API and the server must allow its browser
origin through CORS.

The production UI calls `GET /api/forecast` using city or GPS coordinates and
decodes the server's location, weather, and outfit summary into `Forecast`.
There is no mock fallback. A2 and A3 share one request: loading clears both old
cards, success displays both from the same response, and `WeatherFailure`
displays an error with **Retry** for the original city/GPS action. Connection
errors, timeouts, HTTP failures, invalid JSON/models, and invalid configuration
produce handled messages. Missing optional fields retain the unavailable labels.

Run `flutter test` for URL switching, response decoding, failure handling, and
UI loading/error/retry coverage. For a live smoke test, start the server, run
the app with the appropriate define, search a recognized city, and verify both
cards populate. Stop the server and fetch again to check error/retry; restart
the server and retry. Repeat with your deployed HTTPS URL.

Run `flutter test` for automated A1 coverage (mocked GPS and HTTP): denied
permission followed by city search, GPS coordinates without typing, unknown
city recovery, empty input, no automatic launch request, and malformed responses.
OS permission dialogs and actual GPS still need a device smoke test.

## Running the server

```bash
cd server
npm install
npm start        # http://localhost:3000
```

See [`server/README.md`](server/README.md) for the API contract.

## Project management

- Task list: [`TASKS.md`](TASKS.md)
- GitHub Project board: see the repo's **Projects** tab
- CI: Flutter and server builds run automatically via GitHub Actions on every push/PR (see `.github/workflows/`)

## Demo video

TODO: link the demo video here once recorded (Track D, story D5).
