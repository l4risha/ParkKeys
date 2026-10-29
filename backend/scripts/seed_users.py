"""Seed demo accounts with real bcrypt hashes.

Run from backend/:  python scripts/seed_users.py
Safe to re-run. Requires database/seed_data.sql to have been loaded first.
"""
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.db import connect  # noqa: E402
from app.security import hash_password  # noqa: E402

SEED_USERS = [
    {
        "email": "admin@parkkeys.com",
        "password": "Admin123!",
        "full_name": "Barangay Admin",
        "role": "admin",
    },
    {
        "email": "driver1@parkkeys.com",
        "password": "Driver123!",
        "full_name": "Driver Ramon",
        "role": "driver",
        "tricycle_no": "TRI-001",
        "phone": "09171230001",
    },
    {
        "email": "driver2@parkkeys.com",
        "password": "Driver123!",
        "full_name": "Driver Nilo",
        "role": "driver",
        "tricycle_no": "TRI-002",
        "phone": "09171230002",
    },
    {
        "email": "driver3@parkkeys.com",
        "password": "Driver123!",
        "full_name": "Driver Jose",
        "role": "driver",
        "tricycle_no": "TRI-003",
        "phone": "09171230003",
    },
    {
        "email": "passenger1@parkkeys.com",
        "password": "Passenger123!",
        "full_name": "Passenger Maria",
        "role": "passenger",
    },
    {
        "email": "passenger2@parkkeys.com",
        "password": "Passenger123!",
        "full_name": "Passenger Ana",
        "role": "passenger",
    },
    {
        "email": "passenger3@parkkeys.com",
        "password": "Passenger123!",
        "full_name": "Passenger Ben",
        "role": "passenger",
    },
]


def main() -> None:
    with connect() as conn, conn.transaction():
        for item in SEED_USERS:
            password_hash = hash_password(item["password"])
            user = conn.execute(
                """INSERT INTO users (email, password_hash, full_name, role)
                   VALUES (%s, %s, %s, %s)
                   ON CONFLICT (email) DO UPDATE
                       SET password_hash = EXCLUDED.password_hash,
                           full_name = EXCLUDED.full_name,
                           role = EXCLUDED.role,
                           is_active = TRUE
                   RETURNING id""",
                (item["email"], password_hash, item["full_name"], item["role"]),
            ).fetchone()

            if item["role"] == "driver":
                conn.execute(
                    """INSERT INTO drivers (user_id, tricycle_no, phone)
                       VALUES (%s, %s, %s)
                       ON CONFLICT (user_id) DO UPDATE
                           SET tricycle_no = EXCLUDED.tricycle_no,
                               phone = EXCLUDED.phone,
                               is_active = TRUE""",
                    (user["id"], item["tricycle_no"], item.get("phone")),
                )

    print("Seed users ready (bcrypt hashes set):")
    for item in SEED_USERS:
        print(f"  {item['role']:<9} {item['email']:<28} {item['password']}")


if __name__ == "__main__":
    main()
