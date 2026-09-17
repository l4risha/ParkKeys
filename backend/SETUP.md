# ParkKeys Backend — Sprint 1 & Sprint 2 Setup

## Sprint 1 — repo structure, DB schema, hello world

1. Put this whole `backend/` folder into your repo (it already matches your
   `backend/` folder in the explorer).
2. Create a local PostgreSQL database:
   ```sql
   CREATE DATABASE parkkeys_db;
   CREATE USER parkkeys_user WITH PASSWORD 'parkkeys_pass';
   GRANT ALL PRIVILEGES ON DATABASE parkkeys_db TO parkkeys_user;
   ```
3. In `backend/`:
   ```bash
   python -m venv venv
   venv\Scripts\activate        # Windows (you're on PowerShell per the screenshot)
   pip install -r requirements.txt
   copy .env.example .env       # then edit values if needed
   ```
4. Run it:
   ```bash
   uvicorn main:app --reload
   ```
5. Check the deliverable: open `http://127.0.0.1:8000/` → should return
   `{"message": "ParkKeys API is running", "status": "ok"}`.
   Also check `http://127.0.0.1:8000/docs` (Swagger UI) — this is what
   Sprint 2 testing (Part F) uses for manual endpoint checks.

Starting the app auto-creates the `users` and `drivers` tables via
`Base.metadata.create_all()`. Alternatively, run
`database/migrations/001_create_users_drivers.sql` manually first if you'd
rather use the SQL file directly (matches Part F's "versioned SQL migration
scripts" plan).

## Sprint 2 — register / login

With the server running, test in `/docs` or via curl:

```bash
curl -X POST http://127.0.0.1:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Juan Dela Cruz","email":"juan@parkkeys.test","password":"secret123","role":"passenger"}'

curl -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"juan@parkkeys.test","password":"secret123"}'
```

Both return a JWT `access_token` + the user record — that's your
"working signup/login demo" deliverable for the sprint review.

## Git workflow (matches your Part F plan)

```bash
git checkout -b feature/backend-scaffold
git add backend/ database/
git commit -m "Sprint 1: FastAPI scaffold, DB models, hello world endpoint"
git push -u origin feature/backend-scaffold
# open a PR into main, get one teammate's review, then merge

git checkout -b feature/auth-api
git add backend/auth.py backend/schemas.py
git commit -m "Sprint 2: register/login endpoints with JWT"
git push -u origin feature/auth-api
# PR + review + merge
```
