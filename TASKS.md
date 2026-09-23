# Task List — Weather + Outfit Suggester

20 tasks, written as **user stories** following the **3 C's** (Card,
Conversation, Confirmation):

- **Card** — a short, board-sized summary of what the story is (not a spec).
- **Conversation** — open points the assignee should talk through with the
  team before/while building, rather than a rigid prescription.
- **Confirmation** — the acceptance criteria the "PO" (whoever reviews the
  story) checks off to call it done, i.e. acceptance tests.

Grouped into 4 independent tracks of 5 stories each — one per group member.
Tracks are designed to not block each other: where one track depends on
another's output (e.g. the closet feature matching the server's outfit
categories), the contract is already documented and implemented in
`server/README.md` / `server/src/lib/outfit.js`, so nobody has to wait on a
teammate to start.

These stories are mirrored as GitHub Issues and organized on the repo's
GitHub Project board.

---

## Track A — App Shell & Weather Display

### A1. Enter a location and fetch weather
**Card:** Home screen with a location search field, "Get Weather" button, and device-GPS option with manual fallback.
**Conversation:** What happens on permission denial? Should GPS auto-fetch on launch or require a tap? What's the default/placeholder location?
**Confirmation:**
- Given location permission is denied, I can type a city name and still get a forecast.
- Given permission is granted, tapping "use my location" fills in weather without typing.
- Given an invalid/unrecognized city, I see a clear error, not a crash.

### A2. Display the forecast
**Card:** A widget showing current temp, condition, high/low, and wind from the server response.
**Conversation:** Which fields are "must show" vs "nice to have"? Any unit toggle (F/C) needed for this iteration?
**Confirmation:**
- Given a successful `/api/forecast` response, temp/condition/wind render correctly.
- Given the request is loading, a loading state is shown instead of stale data.
- Given the request fails, an error state is shown with a retry option.

### A3. Show a quick text outfit suggestion
**Card:** A simple card showing the server's outfit `summary` (e.g. "62°F and rainy → jacket, umbrella") as a fallback recommendation.
**Conversation:** This is the baseline shown before/without closet items — how should it visually differ from the closet-based recommendation (Track B)?
**Confirmation:**
- Given a forecast loads, the outfit summary text renders below it.
- Given the forecast updates (new location), the summary updates too.

### A4. Polish the app shell
**Card:** Light/dark theme, pull-to-refresh, empty states, app icon and splash screen.
**Conversation:** Follow system theme or add an in-app toggle? What's the minimum empty-state copy needed?
**Confirmation:**
- Given the OS theme is dark, the app renders in dark mode (or toggle works if added).
- Given I pull down on the forecast screen, it re-fetches.
- Given a fresh install, the app icon and splash screen are branded, not defaults.

### A5. Wire the app to the live server
**Card:** HTTP client + response models connecting the UI to `GET /api/forecast`, with a configurable base URL per environment (local vs. deployed).
**Conversation:** Where does the base URL live (build flavor, `.env`, const)? How are network errors surfaced to A2/A3's states?
**Confirmation:**
- Given the server is reachable, real data (not mocked) populates the UI.
- Given the base URL is switched from localhost to the deployed server, the app works with no code changes.

---

## Track B — Closet Feature (core feature)

### B1. Add a clothing item via camera or upload
**Card:** "Add to Closet" screen with a button that prompts camera access (if available) or lets the user pick a photo from their gallery.
**Conversation:** Which package handles picker + permissions (e.g. `image_picker`)? What happens if camera access is denied — does gallery-only still work?
**Confirmation:**
- Given I tap "Add Item," I'm asked to choose camera or gallery.
- Given I choose camera and haven't granted access, the OS permission prompt appears.
- Given I select/capture a photo, I see a preview before saving.

### B2. Tag a clothing item's details
**Card:** A details form for each item: category (top/bottom/outerwear/accessory), warmth (none/light/medium/heavy), waterproof (yes/no), and an optional name/color.
**Conversation:** Match these fields to the server's outfit contract in `server/README.md` so matching (B4) works without changes later.
**Confirmation:**
- Given I save an item without a category, I'm blocked with a validation message.
- Given I save an item with all fields filled in, it persists and is retrievable after restarting the app.

### B3. View and manage the closet
**Card:** A grid/list screen of saved items with their photos; tap an item to edit or delete it.
**Confirmation:**
- Given I've added items, they appear in the closet grid with their photo thumbnails.
- Given I delete an item, it's removed from the grid and its stored photo is deleted.
- Given I edit an item's tags, the change is reflected immediately.

### B4. Match closet items to today's weather
**Card:** Logic that takes the server's `outfit.items[]` (category/warmth/waterproof) and picks matching items from the user's closet instead of generic text.
**Conversation:** What's the fallback when no closet item matches a category (show Track A3's text suggestion instead, with a prompt to add one)? How to break ties when multiple items match?
**Confirmation:**
- Given the closet has an item tagged `outerwear`/`heavy`/waterproof and the forecast calls for one, that item is selected.
- Given no closet item matches a required category, the app falls back to the plain-text suggestion for that category instead of showing nothing.

### B5. Show a visual "what to wear" screen
**Card:** A screen displaying the photos of the matched closet items (or the fallback text) laid out as today's outfit.
**Confirmation:**
- Given B4 found matching items, their photos display together on this screen.
- Given no matches were found, the fallback text card renders instead, with no broken/blank UI.

---

## Track C — Server

### C1. Combined forecast + outfit endpoint
**Card:** `GET /api/forecast` (already scaffolded in `server/`) returning weather + outfit as one JSON response; harden input validation and error handling (bad city, upstream timeout).
**Confirmation:**
- Given `city` or `lat`/`lon` is missing, the API returns a 400 with a clear error message.
- Given Open-Meteo is unreachable or errors, the API returns a handled error, not a crash/500 with no message.

### C2. Open-Meteo integration
**Card:** Geocode a city name and fetch current weather by lat/long (`server/src/lib/weather.js`, already implemented — review and extend, e.g. handle ambiguous city names).
**Confirmation:**
- Given a common city name, geocoding returns the expected coordinates.
- Given an ambiguous or unknown city, a clear error is returned rather than wrong data.

### C3. Outfit rules engine with the closet-matching contract
**Card:** Rule-based engine (`server/src/lib/outfit.js`, already implemented) mapping temperature/precipitation/wind to outfit items tagged with `category`/`warmth`/`waterproof` for Track B to consume.
**Conversation:** Any new weather scenarios worth adding rules for (e.g. UV index, humidity)?
**Confirmation:**
- Given cold + rainy input, output includes an `outerwear` item and a waterproof `accessory`.
- Given hot + clear input, no `outerwear` item is included.
- All rule branches are covered by unit tests (`server/test/outfit.test.js`).

### C4. Server tests and API docs
**Card:** Integration tests for the API (`server/test/forecast.test.js`) and documentation of the request/response contract (`server/README.md`), already started — extend as the API evolves.
**Confirmation:**
- Given `npm test`, all server tests pass in CI.
- Given a new contributor reads `server/README.md`, they can call the API correctly without reading the source.

### C5. Deploy the server
**Card:** Deploy to a free host (Render/Railway/Fly.io) with environment variables configured, so the app can reach it from a real device, not just localhost.
**Confirmation:**
- Given the deployed URL, `GET /health` returns `{ "status": "ok" }` from the public internet.
- Given the deployed URL, `GET /api/forecast?city=...` returns real data.

---

## Track D — DevOps, Integration, QA, Docs & Demo

### D1. Repo conventions and Project board upkeep
**Card:** Branch protection on `main`/`master`, PR template, `CONTRIBUTING.md`, and keeping the GitHub Project board's issues/status current as work progresses.
**Confirmation:**
- Given a PR is opened, it must pass CI and get a review before merging (branch protection).
- Given the Project board is viewed at any time, its statuses reflect real progress, not all "Todo."

### D2. CI for app and server
**Card:** GitHub Actions workflows (`.github/workflows/flutter-build.yml`, `server-build.yml`, already added) — review, extend with caching/coverage as needed.
**Confirmation:**
- Given a push to any branch, both workflows run and must pass before merge.
- Given a PR touches only `server/`, the Flutter workflow doesn't need to run unnecessarily (path filtering already configured — verify it still makes sense as the app grows).

### D3. End-to-end manual test pass
**Card:** Manually test the full flow — weather fetch, text suggestion, and the closet camera/upload/match/display flow — across at least two platforms (e.g. Android + web).
**Confirmation:**
- A written test log exists covering: happy path, permission-denied path, no-matching-closet-item path, and network-failure path.
- Any bugs found are filed as issues.

### D4. Project documentation
**Card:** Root `README.md` covering setup, architecture (including the closet feature), and how to run the app + server locally.
**Confirmation:**
- Given a new teammate follows the README, they can run the app and server with no other help.
- Architecture section explains how the closet feature and server contract fit together.

### D5. Demo video, final QA, and release
**Card:** Script/record/edit a demo video showing weather + outfit + closet features and what the server adds; run a final bug-bash; tag `v1.0`.
**Confirmation:**
- Demo video is linked in the root README.
- Known blocking bugs are fixed or explicitly logged as known issues before tagging `v1.0`.
