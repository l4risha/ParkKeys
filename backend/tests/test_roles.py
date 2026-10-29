"""Server-side role checks: 401 kung walay token, 403 kung sayop nga role."""
import pytest

PROTECTED_ENDPOINTS = [
    "/api/auth/me",
    "/api/routes",
    "/api/queue/passenger",
    "/api/queue/driver",
    "/api/admin/dashboard",
    "/api/admin/queues",
    "/api/admin/drivers",
    "/api/admin/predictions",
]


@pytest.mark.parametrize("path", PROTECTED_ENDPOINTS)
def test_protected_endpoints_require_token(client, path):
    assert client.get(path).status_code == 401


def test_invalid_token_returns_401(client):
    headers = {"Authorization": "Bearer definitely-not-a-jwt"}
    assert client.get("/api/auth/me", headers=headers).status_code == 401


def test_passenger_and_driver_cannot_access_admin(client, auth):
    assert client.get(
        "/api/admin/dashboard", headers=auth("passenger1@parkkeys.com")
    ).status_code == 403
    assert client.get(
        "/api/admin/dashboard", headers=auth("driver1@parkkeys.com")
    ).status_code == 403
    assert client.get(
        "/api/admin/drivers", headers=auth("passenger1@parkkeys.com")
    ).status_code == 403


def test_wrong_role_cannot_join_other_queue(client, auth, route_id):
    admin = auth("admin@parkkeys.com")
    passenger = auth("passenger1@parkkeys.com")
    driver = auth("driver1@parkkeys.com")

    assert client.post(
        "/api/queue/passenger/join", headers=driver, json={"route_id": route_id}
    ).status_code == 403
    assert client.post(
        "/api/queue/driver/join", headers=passenger, json={"route_id": route_id}
    ).status_code == 403
    assert client.post(
        "/api/queue/driver/join", headers=admin, json={"route_id": route_id}
    ).status_code == 403
    assert client.delete(
        "/api/queue/passenger", headers=admin
    ).status_code == 403


def test_passenger_cannot_serve(client, auth):
    assert client.post(
        "/api/queue/driver/serve", headers=auth("passenger1@parkkeys.com")
    ).status_code == 403
