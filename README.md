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
