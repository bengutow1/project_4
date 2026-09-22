# Task List — Weather + Outfit Suggester

20 tasks total, grouped into 4 tracks of 5. Each track is sized to be one
group member's workload; assign a person to each track once the team is
finalized. These same 20 tasks are mirrored as GitHub Issues and organized
on the repo's GitHub Project board.

## Track A — Flutter Frontend / UI
1. Build the home screen UI: location/city search input, "Get Weather" button, and loading state.
2. Build the forecast display widget: current temperature, condition text/icon, high/low, wind.
3. Build the outfit recommendation card UI (icon + text, e.g. "🧥☂️ Jacket & umbrella").
4. Implement location handling: device geolocation permission flow with manual city-search fallback.
5. Polish the app: error/empty states, pull-to-refresh, light/dark theme, app icon and splash screen.

## Track B — Server (Node.js + Express)
6. Scaffold the Express server (`server/`): project structure, `package.json`, env config, `/health` endpoint.
7. Implement Open-Meteo integration: geocode a city name and fetch current weather by lat/long.
8. Implement the outfit-suggestion rules engine (temperature/precipitation/wind → clothing items) with unit tests.
9. Build the combined `GET /api/forecast` endpoint returning weather + outfit as JSON, with input validation and error handling.
10. Write server integration tests (Jest + Supertest) for the API, and document the API contract in `server/README.md`.

## Track C — DevOps / Repo / Build
11. Set up repo conventions: branch protection on `main`, `.gitignore`, pull request template, `CONTRIBUTING.md`.
12. Configure the GitHub Actions workflow that runs `flutter analyze`, `flutter test`, and a debug APK build on every push/PR.
13. Configure the GitHub Actions workflow that installs deps and runs `npm test` for the server on every push/PR.
14. Deploy the server to a free host (Render/Railway/Fly.io) and configure the Flutter app's API base URL per environment.
15. Set up the GitHub Project board (Backlog / To Do / In Progress / Review / Done), create issues for all 20 tasks, and link PRs to issues.

## Track D — Integration / QA / Docs / Demo
16. Wire the Flutter app to the server API: HTTP client, response models, loading/error states in the UI layer.
17. Run an end-to-end manual test pass across simulated weather conditions (cold/rain, hot/sun, windy) on at least two platforms (e.g. Android + web).
18. Write project documentation: root `README.md` covering setup, architecture, and how to run the app + server locally.
19. Script, record, and edit the demo video (show the app working and explain what the server adds beyond a raw API call); link it in the README.
20. Final QA/bug-bash pass: triage open issues, fix blocking bugs, tag a `v1.0` release, and check submission requirements against the grading rubric.
