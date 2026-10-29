"""Admin CRUD, dashboard, reports, ML predictions."""
from app.db import connect


def test_admin_driver_crud_and_audit(client, auth):
    admin = auth("admin@parkkeys.com")
    created = client.post(
        "/api/admin/drivers",
        headers=admin,
        json={
            "email": "newdriver@parkkeys.com",
            "password": "DriverPass1!",
            "full_name": "New Driver",
            "tricycle_no": "TRI-NEW",
            "phone": "09990001111",
        },
    )
    assert created.status_code == 201, created.text
    driver = created.json()
    assert driver["email"] == "newdriver@parkkeys.com"
    assert driver["is_active"] is True

    duplicate = client.post(
        "/api/admin/drivers",
        headers=admin,
        json={
            "email": "newdriver@parkkeys.com",
            "password": "DriverPass1!",
            "full_name": "Other Driver",
            "tricycle_no": "TRI-OTHER",
        },
    )
    assert duplicate.status_code == 409

    updated = client.patch(
        f"/api/admin/drivers/{driver['id']}",
        headers=admin,
        json={"full_name": "Renamed Driver", "phone": "09990002222"},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["full_name"] == "Renamed Driver"
    assert updated.json()["phone"] == "09990002222"

    deactivated = client.delete(f"/api/admin/drivers/{driver['id']}", headers=admin)
    assert deactivated.status_code == 200, deactivated.text
    assert deactivated.json()["driver_id"] == driver["id"]

    login = client.post(
        "/api/auth/login",
        json={"email": "newdriver@parkkeys.com", "password": "DriverPass1!"},
    )
    assert login.status_code == 403

    with connect() as conn:
        actions = {
            row["action_type"]
            for row in conn.execute(
                "SELECT action_type FROM audit_logs WHERE action_type LIKE 'driver_%'"
            ).fetchall()
        }
    assert {"driver_create", "driver_update", "driver_deactivate"} <= actions


def test_admin_route_crud(client, auth):
    admin = auth("admin@parkkeys.com")
    created = client.post(
        "/api/admin/routes", headers=admin, json={"name": "Test Barangay"}
    )
    assert created.status_code == 201, created.text
    route = created.json()

    duplicate = client.post(
        "/api/admin/routes", headers=admin, json={"name": "Test Barangay"}
    )
    assert duplicate.status_code == 409

    updated = client.patch(
        f"/api/admin/routes/{route['id']}",
        headers=admin,
        json={"name": "Test Barangay Updated", "active": False},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["name"] == "Test Barangay Updated"
    assert updated.json()["active"] is False

    listed = client.get("/api/admin/routes", headers=admin)
    assert any(
        row["id"] == route["id"] and row["active"] is False
        for row in listed.json()
    )

    disabled = client.delete(f"/api/admin/routes/{route['id']}", headers=admin)
    assert disabled.status_code == 200

    with connect() as conn:
        actions = {
            row["action_type"]
            for row in conn.execute(
                "SELECT action_type FROM audit_logs WHERE action_type LIKE 'route_%'"
            ).fetchall()
        }
    assert {"route_create", "route_update", "route_disable"} <= actions


def test_dashboard_uses_real_counts(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    empty = client.get("/api/admin/dashboard", headers=admin)
    assert empty.status_code == 200, empty.text
    assert empty.json()["routes_active"] == 31
    assert empty.json()["drivers_active"] == 2
    assert empty.json()["passengers_waiting"] == 0
    assert empty.json()["drivers_in_queue"] == 0

    assert client.post(
        "/api/queue/passenger/join",
        headers=auth("passenger1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201
    assert client.post(
        "/api/queue/driver/join",
        headers=auth("driver1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201

    busy = client.get("/api/admin/dashboard", headers=admin).json()
    assert busy["passengers_waiting"] == 1
    assert busy["drivers_in_queue"] == 1

    served = client.post("/api/queue/driver/serve", headers=auth("driver1@parkkeys.com"))
    assert served.status_code == 200, served.text

    after = client.get("/api/admin/dashboard", headers=admin).json()
    assert after["passengers_waiting"] == 0
    assert after["drivers_in_queue"] == 0
    assert after["completed_today"] == 1


def test_reports_after_serve(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    assert client.post(
        "/api/queue/passenger/join",
        headers=auth("passenger1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201
    assert client.post(
        "/api/queue/driver/join",
        headers=auth("driver1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201
    assert client.post(
        "/api/queue/driver/serve", headers=auth("driver1@parkkeys.com")
    ).status_code == 200

    report = client.get("/api/admin/reports?days=7", headers=admin)
    assert report.status_code == 200, report.text
    row = next(
        item for item in report.json()["rows"] if item["route_id"] == route_id
    )
    assert row["completed_trips"] == 1


def test_predictions_are_low_medium_high_and_refresh(client, auth):
    admin = auth("admin@parkkeys.com")
    before = client.get("/api/admin/predictions", headers=admin)
    assert before.status_code == 200, before.text
    assert len(before.json()) == 31
    assert {row["demand_level"] for row in before.json()} <= {"LOW", "MEDIUM", "HIGH"}

    refreshed = client.post("/api/admin/predictions/refresh", headers=admin)
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["updated"] == 31
    assert refreshed.json()["errors"] == 0

    after = client.get("/api/admin/predictions", headers=admin)
    assert after.status_code == 200
    assert len(after.json()) == 31
    assert all(
        row["demand_level"] in ("LOW", "MEDIUM", "HIGH") for row in after.json()
    )


def test_deactivating_driver_removes_him_from_queue(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    driver_headers = auth("driver1@parkkeys.com")
    assert client.post(
        "/api/queue/driver/join",
        headers=driver_headers,
        json={"route_id": route_id},
    ).status_code == 201

    drivers = client.get("/api/admin/drivers", headers=admin).json()
    driver = next(row for row in drivers if row["email"] == "driver1@parkkeys.com")
    assert client.delete(f"/api/admin/drivers/{driver['id']}", headers=admin).status_code == 200

    public = client.get(f"/api/public/routes/{route_id}/status").json()
    assert public["drivers_in_queue"] == 0

    with connect() as conn:
        status = conn.execute(
            """SELECT qe.status, qe.reason_code FROM queue_entries qe
                WHERE qe.user_id = (SELECT id FROM users WHERE email = 'driver1@parkkeys.com')"""
        ).fetchone()
        audit = conn.execute(
            "SELECT 1 FROM audit_logs WHERE action_type = 'queue_removed'"
        ).fetchone()
    assert status["status"] == "removed"
    assert status["reason_code"] == "driver_request"
    assert audit is not None


def test_admin_route_queue_monitoring(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    assert client.post(
        "/api/queue/passenger/join",
        headers=auth("passenger1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201
    assert client.post(
        "/api/queue/driver/join",
        headers=auth("driver1@parkkeys.com"),
        json={"route_id": route_id},
    ).status_code == 201

    detail = client.get(f"/api/admin/queues/{route_id}", headers=admin)
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert body["passengers_waiting"] == 1
    assert body["drivers_in_queue"] == 1
    assert body["passengers"][0]["full_name"] == "Test Passenger One"
    assert body["passengers"][0]["position"] == 1
    assert body["drivers"][0]["tricycle_no"] == "TRI-T1"
