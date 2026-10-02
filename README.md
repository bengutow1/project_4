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

For a physical device, point `API_BASE_URL` at the deployed server, e.g.
`flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com`.
See [Deploying](server/README.md#deploying-render) for the URL and free-tier notes.
Android debug builds allow local HTTP; use an HTTPS server for release builds
and Apple devices. Browser GPS requires localhost or HTTPS.

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

TODO: https://drive.google.com/file/d/1mCEZ8Rvv9P6lxenlYwmhjiNY0bbA0aV4/view?usp=sharing
