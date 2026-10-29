"""Queue tests: joins, positions, cancel, driver flow, serve, admin skip."""
import psycopg
import pytest

from app.db import connect


def join_passenger(client, auth, route_id, email="passenger1@parkkeys.com"):
    return client.post(
        "/api/queue/passenger/join",
        headers=auth(email),
        json={"route_id": route_id},
    )


def join_driver(client, auth, route_id, email="driver1@parkkeys.com"):
    return client.post(
        "/api/queue/driver/join",
        headers=auth(email),
        json={"route_id": route_id},
    )


def test_duplicate_active_queue_returns_409(client, auth, route_id):
    headers = auth("passenger1@parkkeys.com")
    first = join_passenger(client, auth, route_id)
    assert first.status_code == 201, first.text

    second = join_passenger(client, auth, route_id)
    assert second.status_code == 409, second.text

    with connect() as conn:
        row = conn.execute(
            """SELECT COUNT(*) AS total FROM queue_entries
                WHERE user_id = (SELECT id FROM users WHERE email = 'passenger1@parkkeys.com')
                  AND status IN ('waiting', 'on_deck')"""
        ).fetchone()
    assert row["total"] == 1


def test_sequential_numbers_and_positions(client, auth, route_id):
    first = join_passenger(client, auth, route_id, "passenger1@parkkeys.com")
    second = join_passenger(client, auth, route_id, "passenger2@parkkeys.com")
    assert first.status_code == 201, first.text
    assert second.status_code == 201, second.text
    assert first.json()["queue_number"] == 1
    assert second.json()["queue_number"] == 2
    assert first.json()["position"] == 1
    assert second.json()["position"] == 2
    assert second.json()["people_ahead"] == 1

    view = client.get("/api/queue/passenger", headers=auth("passenger2@parkkeys.com"))
    assert view.status_code == 200
    assert view.json()["entry"]["people_ahead"] == 1


def test_cancelled_not_counted_as_waiting(client, auth, route_id):
    joined = join_passenger(client, auth, route_id)
    assert joined.status_code == 201, joined.text

    before = client.get(f"/api/public/routes/{route_id}/status")
    assert before.json()["passengers_waiting"] == 1

    cancelled = client.delete(
        "/api/queue/passenger", headers=auth("passenger1@parkkeys.com")
    )
    assert cancelled.status_code == 200, cancelled.text

    after = client.get(f"/api/public/routes/{route_id}/status")
    assert after.json()["passengers_waiting"] == 0

    view = client.get("/api/queue/passenger", headers=auth("passenger1@parkkeys.com"))
    assert view.json()["entry"] is None

    with connect() as conn:
        entry = conn.execute(
            "SELECT status, reason_code FROM queue_entries WHERE id = %s",
            (joined.json()["id"],),
        ).fetchone()
        audit = conn.execute(
            "SELECT action_type FROM audit_logs WHERE action_type = 'queue_cancel'"
        ).fetchone()
    assert entry["status"] == "cancelled"
    assert entry["reason_code"] is None
    assert audit is not None


def test_driver_join_status_and_leave(client, auth, route_id):
    joined = join_driver(client, auth, route_id)
    assert joined.status_code == 201, joined.text
    assert joined.json()["queue_type"] == "driver"
    assert joined.json()["position"] == 1

    view = client.get("/api/queue/driver", headers=auth("driver1@parkkeys.com"))
    assert view.status_code == 200
    assert view.json()["entry"]["queue_number"] == 1
    assert view.json()["passengers_waiting"] == 0

    updated = client.patch(
        "/api/queue/driver/status",
        headers=auth("driver1@parkkeys.com"),
        json={"status": "on_deck"},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["status"] == "on_deck"

    left = client.delete("/api/queue/driver", headers=auth("driver1@parkkeys.com"))
    assert left.status_code == 200, left.text
    assert client.get(
        "/api/queue/driver", headers=auth("driver1@parkkeys.com")
    ).json()["entry"] is None


def test_serve_completes_both_and_recomputes_positions(client, auth, route_id):
    passenger_one = join_passenger(client, auth, route_id, "passenger1@parkkeys.com")
    passenger_two = join_passenger(client, auth, route_id, "passenger2@parkkeys.com")
    driver = join_driver(client, auth, route_id, "driver1@parkkeys.com")
    assert passenger_one.status_code == 201
    assert passenger_two.status_code == 201
    assert driver.status_code == 201

    served = client.post("/api/queue/driver/serve", headers=auth("driver1@parkkeys.com"))
    assert served.status_code == 200, served.text
    body = served.json()
    assert body["passenger_entry_id"] == passenger_one.json()["id"]
    assert body["driver_entry_id"] == driver.json()["id"]
    assert body["passenger_queue_number"] == 1
    assert body["driver_queue_number"] == 1

    with connect() as conn:
        statuses = conn.execute(
            """SELECT id, status, completed_at FROM queue_entries
                WHERE id = ANY(%s) ORDER BY id""",
            ([passenger_one.json()["id"], driver.json()["id"]],),
        ).fetchall()
        dispatch = conn.execute(
            "SELECT * FROM dispatch_logs WHERE passenger_entry_id = %s",
            (passenger_one.json()["id"],),
        ).fetchone()
        audit = conn.execute(
            "SELECT details FROM audit_logs WHERE action_type = 'queue_serve'"
        ).fetchone()
    assert len(statuses) == 2
    assert all(row["status"] == "completed" for row in statuses)
    assert all(row["completed_at"] is not None for row in statuses)
    assert dispatch is not None
    assert audit is not None

    # Ang sunod nga passenger ni-move na sa position 1.
    next_in_line = client.get(
        "/api/queue/passenger", headers=auth("passenger2@parkkeys.com")
    )
    assert next_in_line.status_code == 200
    assert next_in_line.json()["entry"]["position"] == 1
    assert next_in_line.json()["entry"]["people_ahead"] == 0

    # Driver wala nay active entry.
    assert client.get(
        "/api/queue/driver", headers=auth("driver1@parkkeys.com")
    ).json()["entry"] is None


def test_driver_at_position_two_cannot_serve(client, auth, route_id):
    assert join_passenger(client, auth, route_id).status_code == 201
    assert join_driver(client, auth, route_id, "driver1@parkkeys.com").status_code == 201
    assert join_driver(client, auth, route_id, "driver2@parkkeys.com").status_code == 201

    blocked = client.post("/api/queue/driver/serve", headers=auth("driver2@parkkeys.com"))
    assert blocked.status_code == 409, blocked.text

    allowed = client.post("/api/queue/driver/serve", headers=auth("driver1@parkkeys.com"))
    assert allowed.status_code == 200, allowed.text


def test_serve_without_passenger_returns_409(client, auth, route_id):
    assert join_driver(client, auth, route_id).status_code == 201
    response = client.post("/api/queue/driver/serve", headers=auth("driver1@parkkeys.com"))
    assert response.status_code == 409


def test_join_inactive_route_returns_400(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    disabled = client.patch(
        f"/api/admin/routes/{route_id}", headers=admin, json={"active": False}
    )
    assert disabled.status_code == 200, disabled.text

    response = join_passenger(client, auth, route_id)
    assert response.status_code == 400
    assert "inactive" in response.json()["detail"].lower()


def test_admin_skip_requires_reason(client, auth, route_id):
    passenger = join_passenger(client, auth, route_id)
    entry_id = passenger.json()["id"]
    admin = auth("admin@parkkeys.com")

    missing = client.post(f"/api/admin/queue/{entry_id}/skip", headers=admin, json={})
    assert missing.status_code == 422, missing.text

    invalid = client.post(
        f"/api/admin/queue/{entry_id}/skip",
        headers=admin,
        json={"reason_code": "bogus"},
    )
    assert invalid.status_code == 422, invalid.text

    valid = client.post(
        f"/api/admin/queue/{entry_id}/skip",
        headers=admin,
        json={"reason_code": "no_show"},
    )
    assert valid.status_code == 200, valid.text
    assert valid.json()["status"] == "skipped"
    assert valid.json()["reason_code"] == "no_show"

    with connect() as conn:
        row = conn.execute(
            "SELECT status, reason_code FROM queue_entries WHERE id = %s", (entry_id,)
        ).fetchone()
        audit = conn.execute(
            "SELECT details FROM audit_logs WHERE action_type = 'queue_skipped'"
        ).fetchone()
    assert row["status"] == "skipped"
    assert row["reason_code"] == "no_show"
    assert audit is not None


def test_admin_remove_with_reason(client, auth, route_id):
    passenger = join_passenger(client, auth, route_id)
    entry_id = passenger.json()["id"]
    admin = auth("admin@parkkeys.com")

    removed = client.post(
        f"/api/admin/queue/{entry_id}/remove",
        headers=admin,
        json={"reason_code": "other"},
    )
    assert removed.status_code == 200, removed.text
    assert removed.json()["status"] == "removed"

    with connect() as conn:
        row = conn.execute(
            "SELECT status, reason_code FROM queue_entries WHERE id = %s", (entry_id,)
        ).fetchone()
    assert row["status"] == "removed"
    assert row["reason_code"] == "other"


def test_database_partial_index_and_reason_check(client, auth, route_id):
    with connect() as conn:
        index = conn.execute(
            "SELECT indexdef FROM pg_indexes WHERE indexname = 'one_active_queue_per_user'"
        ).fetchone()
        assert index is not None
        assert "WHERE" in index["indexdef"]

        passenger = conn.execute(
            "SELECT id FROM users WHERE email = 'passenger1@parkkeys.com'"
        ).fetchone()
        first = conn.execute(
            """INSERT INTO queue_entries (route_id, user_id, queue_type, queue_number)
               VALUES (%s, %s, 'passenger', 1) RETURNING id""",
            (route_id, passenger["id"]),
        ).fetchone()
        conn.commit()

        with pytest.raises(psycopg.errors.UniqueViolation):
            conn.execute(
                """INSERT INTO queue_entries (route_id, user_id, queue_type, queue_number)
                   VALUES (%s, %s, 'passenger', 2)""",
                (route_id, passenger["id"]),
            )
        conn.rollback()

        with pytest.raises(psycopg.errors.CheckViolation):
            conn.execute(
                "UPDATE queue_entries SET status = 'skipped' WHERE id = %s",
                (first["id"],),
            )
        conn.rollback()
