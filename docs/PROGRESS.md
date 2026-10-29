# ParkKeys Progress Log

New session? Read this file first, then `AGENTS.md` (the spec), then `docs/ASSUMPTIONS.md`.

Status legend: `[x]` done and verified, `[ ]` not done.

## Backend build (current phase)

- [x] Step 0: Read spec, checked environment (Python 3.12, PostgreSQL 18 installed).
- [x] Step 1: Repo setup: `.gitignore` (ignores `.env`, `venv/`, `__pycache__/`, `build/`, `.dart_tool/`),
      `.env.example`, README with exact run commands, `scripts/setup_db.ps1`, spec in `AGENTS.md`.
- [x] Step 2: `database/schema.sql` (7 tables + partial unique index + reason CHECK),
      `database/seed_data.sql` (31 barangays, demo users, 30-day synthetic demand history),
      `backend/scripts/seed_users.py` (real bcrypt cost 12 hashes).
      Verified by loading into PostgreSQL and running the seed script.
- [x] Step 3: FastAPI core: `.env` config, psycopg connection, bcrypt + JWT,
      POST `/api/auth/register`, POST `/api/auth/login`, GET `/api/auth/me`,
      GET `/api/routes?search=`. Verified with TestClient and live uvicorn.
- [x] Step 4: Queue API: passenger join/view/cancel; driver join/view/status/leave;
      sequential numbers with advisory lock; DB-computed positions/people ahead;
      duplicate active entry 409; audit logs on join/cancel/status. Verified by pytest.
- [x] Step 5: Driver serve endpoint (one transaction, dispatch + audit + completion),
      admin skip/remove with required reason, driver CRUD, route CRUD,
      queue monitoring, dashboard, reports, ML predictions + 30-minute refresh.
      Verified by pytest and live HTTP calls.
- [x] Step 6: Public no-login `GET /api/public/routes` and
      `GET /api/public/routes/{id}/status`. Verified live (200 with no token, real counts).
- [x] Step 7: pytest suite (39 tests). **Real result: `39 passed in 26.15s`**.
      Covered duplicate email 409, duplicate active queue 409, 31 unique barangays,
      cancelled not waiting, serve completes both entries, skip without reason 422,
      401/403 role checks, DB partial index + reason CHECK, public endpoints.
      Also verified `python -m compileall` OK.

## Verification evidence (real, not claimed)

- PostgreSQL seed load: routes `INSERT 0 31`, users `INSERT 0 7`, drivers `INSERT 0 3`,
  demand history `INSERT 0 21607`.
- ML refresh against the dev DB:
  `{'updated': 31, 'model_version': 'rf-hourly-v1', 'errors': 0}`
  with a mix of HIGH/MEDIUM/LOW predictions.
- Live uvicorn smoke test on port 8000:
  health 200, `/docs` 200, OpenAPI 25 paths, passenger join 201 (ticket 1),
  duplicate join 409, driver join 201, serve 200, skip without reason 422,
  skip with reason 200, wrong role 403, public routes 200 without login.
- `scripts/setup_db.ps1` was run against a fresh database name:
  CREATE DATABASE, schema load, 31 routes + users + 21607 demand rows, seed users all OK.
- pytest run command: `backend\venv\Scripts\python.exe -m pytest` (from `backend/`).

## Frontend build (current phase)

- [x] Step 8: Flutter Web scaffold (`frontend/`): Provider, `http`, GoRouter,
      `shared_preferences`. One API config (`lib/config.dart`), HTTP client with JWT
      (`lib/services/api_client.dart`), auth state (`lib/state/auth_state.dart`),
      Login/Register screens, role-based GoRouter guards (`lib/router.dart`).
- [x] Step 9: Passenger dashboard (searchable barangay picker, live waiting/driver
      counts, Join Queue, ticket number / passengers ahead / status, View, Cancel) and
      driver dashboard (select route, join, position, waiting/on_deck status, Complete
      Trip, Leave Queue). Both poll every 3 seconds.
- [x] Step 10: Admin screens: dashboard cards + ML demand list, Manage Drivers
      (add/edit/deactivate/reactivate), Manage Routes (add/rename/disable/enable),
      Queue Monitoring per barangay, and skip/remove dialog with required reason code.
- [x] Step 11: Public no-login board at `/public` with per-barangay drivers in queue,
      passengers waiting, demand level, search, and driver-list dialog.
- [x] Step 12: Verification (real output below) + README commands + manual UI checklist.

## Frontend verification evidence (real, not claimed)

- `cd frontend; flutter analyze` -> **`No issues found! (ran in 27.2s)`**.
- `cd frontend; flutter test` -> **`5 passed, 2 skipped`** (the 2 skipped are the
  opt-in live API tests).
- `flutter test --dart-define=LIVE_API=true test/live_api_test.dart` -> **`2 passed`**.
  It logs in as admin, driver, and passenger through the real API, calls `/api/auth/me`,
  and checks 31 routes, admin dashboard, admin queues, and the public board.
- `flutter run -d chrome --web-port=5000 --web-hostname=127.0.0.1` -> compiled, opened
  Chrome with title **ParkKeys**, and served <http://127.0.0.1:5000> (HTTP 200).
  GoRouter hash routes were observed for `/login`, `/public`, `/admin`, and `/driver`.
- `flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000` ->
  **`√ Built build\web`** (release bundle compiles).
- During the live Chrome session, `audit_logs` recorded real UI actions:
  passenger `queue_join` on Caasinan (19:15:48), driver `queue_join` (19:16:46),
  four `queue_status` updates, and `queue_serve` (19:17:10).
- Widget tests cover the login form wiring for all 3 roles and empty-field validation.

## Notes
- Real DB used for verification: project-local PostgreSQL cluster on port **5433**
  (`.pgdata/`, gitignored) because the system PostgreSQL password was unavailable.
  The app does not depend on 5433; update `DATABASE_URL` for your own server.
- Test DB is `parkkeys_test` (auto-created). Tests never touch `parkkeys_db`.
- Frontend: API base URL defaults to `http://127.0.0.1:8000`; override with
  `--dart-define=API_BASE_URL=...`. JWT is kept in browser localStorage for reloads.
  No backend changes were needed for the frontend.

