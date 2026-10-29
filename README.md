# ParkKeys

Barangay-based tricycle queue management system for Cabadbaran City.
This repository contains the **backend** (FastAPI + PostgreSQL + scikit-learn) and the
**Flutter Web frontend** (`frontend/`).

Spec: [`AGENTS.md`](AGENTS.md) | Assumptions: [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) | Progress: [`docs/PROGRESS.md`](docs/PROGRESS.md)

## Stack and folders

| Folder | Purpose |
| --- | --- |
| `backend/` | FastAPI app, seed scripts, pytest suite |
| `database/` | `schema.sql`, `seed_data.sql` |
| `docs/` | assumptions and progress log |
| `frontend/` | Flutter Web app (Provider + GoRouter + polling REST client) |

## Prerequisites

- Python 3.11+ (verified on Python 3.12)
- PostgreSQL 15+ (verified on PostgreSQL 18)
- `psql` on PATH
- Flutter 3.47+ stable (verified on Flutter 3.47.4 / Dart 3.13.3)
- Google Chrome (for `flutter run -d chrome`)
- Git

## 1. Create and load the database

Run from the repository root. `psql` will ask for the PostgreSQL password.

```powershell
psql -U postgres -h localhost -p 5432 -c "CREATE DATABASE parkkeys_db;"
psql -U postgres -h localhost -p 5432 -d parkkeys_db -v ON_ERROR_STOP=1 -f database/schema.sql
psql -U postgres -h localhost -p 5432 -d parkkeys_db -v ON_ERROR_STOP=1 -f database/seed_data.sql
```

The seed file inserts:

- exactly **31 barangays** into `routes`
- 1 admin, 3 drivers, 3 passengers (placeholder password hashes)
- 30 days of synthetic hourly demand history for the ML demo

Then set the real bcrypt hashes for the demo accounts:

```powershell
cd backend
python scripts/seed_users.py
```

Or use the repeatable setup script (create DB if needed, schema, seed, users):

```powershell
$env:PGPASSWORD = "your-postgres-password"
.\scripts\setup_db.ps1
```

## 2. Configure and run the backend

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item ..\.env.example .env
```

Edit `backend/.env` and set your real database URL:

```dotenv
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/parkkeys_db
JWT_SECRET=make-this-long-and-random
```

Start the API:

```powershell
uvicorn app.main:app --reload --port 8000
```

- Swagger UI: <http://127.0.0.1:8000/docs>
- OpenAPI JSON: <http://127.0.0.1:8000/openapi.json>
- Health: <http://127.0.0.1:8000/api/health>

CORS is enabled (`CORS_ORIGINS=*` by default) so Flutter Web can call the API.
Flutter never connects to PostgreSQL and never receives DB/JWT secrets.

### Demo accounts (after `seed_users.py`)

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@parkkeys.com` | `Admin123!` |
| Driver | `driver1@parkkeys.com` | `Driver123!` |
| Driver | `driver2@parkkeys.com` | `Driver123!` |
| Driver | `driver3@parkkeys.com` | `Driver123!` |
| Passenger | `passenger1@parkkeys.com` | `Passenger123!` |
| Passenger | `passenger2@parkkeys.com` | `Passenger123!` |
| Passenger | `passenger3@parkkeys.com` | `Passenger123!` |

Passwords are hashed with the `bcrypt` package directly, cost 12.

## 3. Run the Flutter Web frontend

Keep the backend running on port 8000, then:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port=5000 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Open <http://127.0.0.1:5000>. The API URL defaults to `http://127.0.0.1:8000`,
so `--dart-define` is optional. For a deployed API:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```

The static build is in `frontend/build/web` (serve it from any static host).

Frontend structure:

| File | Purpose |
| --- | --- |
| `lib/config.dart` | API base URL + 3-second poll interval |
| `lib/services/api_client.dart` | HTTP wrapper, attaches JWT, API error messages |
| `lib/state/auth_state.dart` | login/register/logout, token restore, role home |
| `lib/router.dart` | GoRouter routes + role guards |
| `lib/screens/` | login, register, passenger, driver, admin, public board |
| `lib/widgets/` | polling mixin, shared responsive widgets |

Notes:

- JWT is saved in browser `localStorage` via `shared_preferences`; reload keeps login.
- Every screen polls the API every 3 seconds. No WebSocket.
- GoRouter guards hide the wrong dashboard, but the backend still enforces roles.
- Admin pages: `/admin`, `/admin/drivers`, `/admin/routes`, `/admin/queues`.
- Public no-login board: `/public`.

### Frontend checks

```powershell
cd frontend
flutter analyze
flutter test
```

Optional live test against the running backend (verifies login for all 3 seeded roles,
the admin dashboard, and the public board):

```powershell
flutter test --dart-define=LIVE_API=true test/live_api_test.dart
```

## 4. Run the tests

The suite creates a **separate** `_test` database (it refuses names that do not end in `_test`).
By default it derives `parkkeys_test` from `DATABASE_URL`.

```powershell
cd backend
$env:TEST_DATABASE_URL = "postgresql://postgres:YOUR_PASSWORD@localhost:5432/parkkeys_test"
.\venv\Scripts\python.exe -m pytest
```

The PostgreSQL user needs permission to `CREATE DATABASE`.

## API overview

### Auth
| Method | Path | Role |
| --- | --- | --- |
| POST | `/api/auth/register` | public (creates passenger only) |
| POST | `/api/auth/login` | public |
| GET | `/api/auth/me` | any logged-in user |

### Routes and queues
| Method | Path | Role |
| --- | --- | --- |
| GET | `/api/routes?search=` | any logged-in user |
| POST | `/api/queue/passenger/join` | passenger |
| GET | `/api/queue/passenger` | passenger |
| DELETE | `/api/queue/passenger` | passenger |
| POST | `/api/queue/driver/join` | driver |
| GET | `/api/queue/driver` | driver |
| PATCH | `/api/queue/driver/status` | driver (`waiting` / `on_deck`) |
| POST | `/api/queue/driver/serve` | driver at position 1 |
| DELETE | `/api/queue/driver` | driver |

### Admin
| Method | Path | Purpose |
| --- | --- | --- |
| GET/POST | `/api/admin/drivers` | list / add driver |
| PATCH/DELETE | `/api/admin/drivers/{id}` | edit / deactivate driver |
| GET/POST | `/api/admin/routes` | list (including inactive) / add route |
| PATCH/DELETE | `/api/admin/routes/{id}` | edit / disable route |
| GET | `/api/admin/queues` | live counts per barangay |
| GET | `/api/admin/queues/{route_id}` | live entries with positions |
| POST | `/api/admin/queue/{entry_id}/skip` | skip (reason required) |
| POST | `/api/admin/queue/{entry_id}/remove` | remove (reason required) |
| GET | `/api/admin/dashboard` | dashboard statistics |
| GET | `/api/admin/reports?days=7` | per-route report |
| GET | `/api/admin/predictions` | LOW / MEDIUM / HIGH per barangay |
| POST | `/api/admin/predictions/refresh` | force ML refresh now |

### Public (no login)
| Method | Path |
| --- | --- |
| GET | `/api/public/routes` |
| GET | `/api/public/routes/{route_id}/status` |

Reason codes for skip/remove: `no_show`, `vehicle_issue`, `driver_request`, `other`.
Missing or invalid reason returns **422** before any database change.

## Queue rules in one minute

- One active entry per user is enforced by the partial unique index
  `one_active_queue_per_user`; the API returns **409** on duplicates.
- Queue numbers are assigned per `(route, queue_type)` at join time and never change.
- Position / people ahead are computed live from active rows (`waiting`, `on_deck`).
- Serving completes the position-1 driver and position-1 passenger of the same route
  in **one transaction**, writes `dispatch_logs` and `audit_logs`, and the next
  passengers automatically move to position 1.
- Inactive routes cannot receive new queue entries (`400`).

## ML demand prediction

- One small `RandomForestRegressor` per route, trained on `demand_history`
  (features: hour of day, day of week). This is simple enough to defend.
- Counts become `LOW` (<4), `MEDIUM` (<8), `HIGH` (>=8).
- Refresh runs at startup and every 30 minutes (`ML_REFRESH_MINUTES`).
- If training/reading fails or there is no history, the API returns a rule-based
  fallback and the main API keeps working. It never crashes because of ML.
- Manual demo refresh: `POST /api/admin/predictions/refresh` (admin token).

## Manual Swagger checklist

1. `POST /api/auth/login` with `admin@parkkeys.com` / `Admin123!`; copy `access_token`.
2. Click **Authorize** in Swagger and paste the token (Bearer auth).
3. `GET /api/auth/me` -> role must be `admin`.
4. `GET /api/routes?search=poblacion` -> 12 Poblacion routes.
5. Login as `passenger1@parkkeys.com`, call `POST /api/queue/passenger/join`
   with a real `route_id`, then `GET /api/queue/passenger` -> number, position, people ahead.
6. Call join again -> **409**.
7. Login as `driver1@parkkeys.com`, join the same route, then
   `POST /api/queue/driver/serve` -> both entries completed.
8. Login as admin, `GET /api/admin/queues/{route_id}` -> queues reflect the serve.
9. Admin skip an active entry with `{}` -> **422**; retry with `{"reason_code":"no_show"}` -> **200**.
10. Logout/remove token and call `GET /api/public/routes` -> **200** without login.
11. Passenger token on `/api/admin/dashboard` -> **403**.
12. `GET /api/admin/predictions` -> 31 rows with LOW/MEDIUM/HIGH.

## Manual UI checklist (Flutter Web)

1. Open <http://127.0.0.1:5000/public> (or click **View public queue board**).
   You should see all 31 barangays with live passenger/driver counts and demand chips,
   with no login. Tap a card to see the driver list.
2. Login as `passenger1@parkkeys.com` / `Passenger123!`.
   Search and select a barangay, click **Join Queue**, and confirm the queue number,
   passengers ahead, and status. Wait 3 seconds -> counts update automatically.
   Open **View** for details, then **Cancel Queue**.
3. Login as `driver1@parkkeys.com` / `Driver123!`.
   Select the same route and **Join Driver Queue**. Check position and queue number.
   Toggle **On deck**, and use **Complete Trip** when position is 1 and a passenger waits.
4. Login as `admin@parkkeys.com` / `Admin123!`.
   Check the four dashboard cards (total drivers, active drivers, passengers served today,
   active queues) and the ML demand list. Then:
   - **Drivers**: add, edit, deactivate, reactivate a driver.
   - **Routes**: add, rename, disable, re-enable a barangay.
   - **Queues**: open a barangay, then **Skip** or **Remove** an entry.
     Submitting without a reason must be blocked; the reason codes are
     `no_show`, `vehicle_issue`, `driver_request`, `other`.
5. Logout. While logged in as a passenger, open `/admin` in the URL bar ->
   the guard sends you back to `/passenger`.
6. Resize the window from 360px to 1920px: navigation switches between bottom bar
   and side rail, cards reflow, and no horizontal scrolling appears.

## Troubleshooting

- **`psql: password authentication failed`** -> set the real password in `.env`
  and use `$env:PGPASSWORD` for commands.
- **`bcrypt` install error on Windows** -> use Python 3.12 x64 and upgrade pip.
- **Port 8000 busy** -> `uvicorn app.main:app --port 8001` and run Flutter with
  `--dart-define=API_BASE_URL=http://127.0.0.1:8001`.
- **Flutter shows "Cannot reach the API"** -> check the backend URL and that CORS allows
  the Flutter origin (`CORS_ORIGINS=*` is fine for the demo).
- **Port 5000 busy** -> use another `--web-port`.
- **Tests create `parkkeys_test`** -> expected; they never touch `parkkeys_db`.
