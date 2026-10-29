"""pytest setup: creates a separate `_test` database, resets data per test."""
import os
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import bcrypt
import psycopg
import pytest
from dotenv import load_dotenv
from psycopg.rows import dict_row

BACKEND_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = BACKEND_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))
load_dotenv(BACKEND_DIR / ".env")

DEFAULT_URL = "postgresql://postgres:postgres@localhost:5432/parkkeys_db"


def _with_database(url: str, database: str) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, f"/{database}", parts.query, ""))


_source_url = os.getenv("TEST_DATABASE_URL") or os.getenv("DATABASE_URL") or DEFAULT_URL
_source_db = urlsplit(_source_url).path.lstrip("/") or "parkkeys_db"
if not _source_db.endswith("_test"):
    _source_db = _source_db + "_test"
TEST_DATABASE_URL = _with_database(_source_url, _source_db)

# Import app AFTER env is set. Dili kalabasan ang dev database.
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ["JWT_SECRET"] = "pytest-only-secret-that-is-at-least-32-bytes-long"
os.environ["ML_ENABLED"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

from app.db import connect  # noqa: E402
from app.main import app  # noqa: E402

TEST_PASSWORD = "Passw0rd!"
PASSWORD_HASH = bcrypt.hashpw(
    TEST_PASSWORD.encode(), bcrypt.gensalt(rounds=10)
).decode()

TEST_USERS = [
    ("admin@parkkeys.com", "Test Admin", "admin", None),
    ("driver1@parkkeys.com", "Test Driver One", "driver", "TRI-T1"),
    ("driver2@parkkeys.com", "Test Driver Two", "driver", "TRI-T2"),
    ("passenger1@parkkeys.com", "Test Passenger One", "passenger", None),
    ("passenger2@parkkeys.com", "Test Passenger Two", "passenger", None),
]
SEEDED_ROUTE_NAMES: set[str] = set()


def _ensure_database() -> None:
    database = urlsplit(TEST_DATABASE_URL).path.lstrip("/")
    if not database.endswith("_test"):
        raise RuntimeError(f"Refusing to use non-test database: {database}")
    maintenance = _with_database(TEST_DATABASE_URL, "postgres")
    with psycopg.connect(maintenance, autocommit=True) as conn:
        exists = conn.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s", (database,)
        ).fetchone()
        if not exists:
            from psycopg import sql

            conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database)))


def _reset_schema() -> None:
    schema_sql = (ROOT_DIR / "database" / "schema.sql").read_text(encoding="utf-8")
    seed_sql = (ROOT_DIR / "database" / "seed_data.sql").read_text(encoding="utf-8")
    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
        conn.execute(schema_sql)
        conn.execute(seed_sql)


def _insert_test_users(conn) -> None:
    for email, full_name, role, tricycle_no in TEST_USERS:
        user = conn.execute(
            """INSERT INTO users (email, password_hash, full_name, role)
               VALUES (%s, %s, %s, %s) RETURNING id""",
            (email, PASSWORD_HASH, full_name, role),
        ).fetchone()
        if tricycle_no:
            conn.execute(
                "INSERT INTO drivers (user_id, tricycle_no, phone) VALUES (%s, %s, %s)",
                (user["id"], tricycle_no, "09000000000"),
            )


def pytest_sessionstart(session):
    _ensure_database()
    _reset_schema()
    global SEEDED_ROUTE_NAMES
    with psycopg.connect(TEST_DATABASE_URL, row_factory=dict_row) as conn:
        SEEDED_ROUTE_NAMES = {
            row["name"] for row in conn.execute("SELECT name FROM routes").fetchall()
        }


@pytest.fixture(autouse=True)
def reset_data():
    with connect() as conn, conn.transaction():
        conn.execute(
            """TRUNCATE queue_entries, dispatch_logs, audit_logs, predictions,
                        demand_history, drivers, users RESTART IDENTITY CASCADE"""
        )
        # Restore baseline routes (delete test-created ones, re-enable seeded ones).
        conn.execute(
            "DELETE FROM routes WHERE NOT (name = ANY(%s))", (list(SEEDED_ROUTE_NAMES),)
        )
        conn.execute("UPDATE routes SET active = TRUE")
        _insert_test_users(conn)
    yield


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def auth(client):
    cache: dict[str, dict] = {}

    def _login(email: str) -> dict:
        if email not in cache:
            response = client.post(
                "/api/auth/login",
                json={"email": email, "password": TEST_PASSWORD},
            )
            assert response.status_code == 200, response.text
            cache[email] = {
                "Authorization": f"Bearer {response.json()['access_token']}"
            }
        return cache[email]

    return _login


@pytest.fixture
def routes_by_name(client, auth):
    response = client.get("/api/admin/routes", headers=auth("admin@parkkeys.com"))
    assert response.status_code == 200
    return {route["name"]: route["id"] for route in response.json()}


@pytest.fixture
def route_id(routes_by_name):
    return routes_by_name["Poblacion 1"]
