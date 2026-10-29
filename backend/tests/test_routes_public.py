"""Routes, 31 barangays, search, public endpoints."""
from tests.conftest import SEEDED_ROUTE_NAMES

EXPECTED_BARANGAYS = {
    "Antonio Luna", "Bay-ang", "Bayabas", "Caasinan", "Cabinet", "Calamba",
    "Calibunan", "Comagascas", "Concepcion", "Del Pilar", "Katugasan",
    "Kauswagan", "La Union", "Mabini", "Mahaba", "Puting Bato", "Sanghan",
    "Soriano", "Tolosa",
} | {f"Poblacion {n}" for n in range(1, 13)}


def test_health_endpoints(client):
    for path in ("/health", "/api/health"):
        response = client.get(path)
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


def test_exactly_31_unique_barangays(client, auth):
    response = client.get("/api/admin/routes", headers=auth("admin@parkkeys.com"))
    assert response.status_code == 200
    routes = response.json()
    names = [route["name"] for route in routes]
    assert len(names) == 31
    assert len(set(names)) == 31
    assert set(names) == EXPECTED_BARANGAYS
    assert SEEDED_ROUTE_NAMES == EXPECTED_BARANGAYS


def test_route_search(client, auth):
    headers = auth("passenger1@parkkeys.com")
    response = client.get("/api/routes?search=poblacion", headers=headers)
    assert response.status_code == 200
    assert len(response.json()) == 12
    assert all("Poblacion" in row["name"] for row in response.json())

    empty = client.get("/api/routes?search=zzz-no-such-barangay", headers=headers)
    assert empty.status_code == 200
    assert empty.json() == []


def test_routes_require_login(client):
    assert client.get("/api/routes").status_code == 401


def test_public_routes_need_no_login_and_have_real_counts(client, auth, route_id):
    public = client.get("/api/public/routes")
    assert public.status_code == 200
    assert len(public.json()) == 31
    for row in public.json():
        assert row["passengers_waiting"] == 0
        assert row["drivers_in_queue"] == 0
        assert row["demand_level"] in ("LOW", "MEDIUM", "HIGH")

    joined = client.post(
        "/api/queue/passenger/join",
        headers=auth("passenger1@parkkeys.com"),
        json={"route_id": route_id},
    )
    assert joined.status_code == 201, joined.text

    status = client.get(f"/api/public/routes/{route_id}/status")
    assert status.status_code == 200
    body = status.json()
    assert body["passengers_waiting"] == 1
    assert body["drivers_in_queue"] == 0
    assert body["drivers"] == []
    assert body["demand_level"] in ("LOW", "MEDIUM", "HIGH")
    assert body["updated_at"]


def test_public_unknown_route_404(client):
    assert client.get("/api/public/routes/999999/status").status_code == 404
