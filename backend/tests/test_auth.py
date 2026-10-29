"""Auth tests: register, login, duplicate email, 401."""
from tests.conftest import TEST_PASSWORD


def test_register_passenger_and_me(client):
    response = client.post(
        "/api/auth/register",
        json={
            "email": "newpassenger@parkkeys.com",
            "password": "Secret123!",
            "full_name": "New Passenger",
        },
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["user"]["role"] == "passenger"
    assert body["token_type"] == "bearer"

    headers = {"Authorization": f"Bearer {body['access_token']}"}
    me = client.get("/api/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "newpassenger@parkkeys.com"
    assert me.json()["role"] == "passenger"


def test_duplicate_email_returns_409(client):
    payload = {
        "email": "duplicate@parkkeys.com",
        "password": "Secret123!",
        "full_name": "Duplicate User",
    }
    first = client.post("/api/auth/register", json=payload)
    assert first.status_code == 201, first.text

    second = client.post("/api/auth/register", json=payload)
    assert second.status_code == 409, second.text
    assert "already" in second.json()["detail"].lower()


def test_login_wrong_password_returns_401(client):
    response = client.post(
        "/api/auth/login",
        json={"email": "passenger1@parkkeys.com", "password": "WrongPassword1!"},
    )
    assert response.status_code == 401


def test_login_success_returns_role_claim(client):
    response = client.post(
        "/api/auth/login",
        json={"email": "driver1@parkkeys.com", "password": TEST_PASSWORD},
    )
    assert response.status_code == 200, response.text
    assert response.json()["user"]["role"] == "driver"
    assert response.json()["access_token"]
