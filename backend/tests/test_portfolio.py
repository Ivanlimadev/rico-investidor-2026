def _register(client, *, email: str = "carteira@example.com"):
    response = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": "Senha-forte123!",
            "name": "Carteira Teste",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def test_portfolio_requires_registered_user(client, auth_env):
    anon = client.post("/v1/auth/anonymous", json={"device_id": "device-portfolio-1"}).json()[
        "access_token"
    ]
    response = client.get(
        "/v1/portfolio/holdings",
        headers={"Authorization": f"Bearer {anon}"},
    )
    assert response.status_code == 403


def test_portfolio_crud_flow(client, auth_env):
    token = _register(client, email="crud@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    empty = client.get("/v1/portfolio/holdings", headers=headers)
    assert empty.status_code == 200
    assert empty.json()["count"] == 0

    created = client.post(
        "/v1/portfolio/holdings",
        headers=headers,
        json={
            "symbol": "AAPL",
            "name": "Apple Inc",
            "quantity": 2,
            "average_price": 150.0,
            "current_price": 175.0,
            "change_percent": 1.2,
            "currency": "usd",
            "category": "stocks",
        },
    )
    assert created.status_code == 200
    body = created.json()
    assert body["count"] == 1
    holding_id = body["items"][0]["id"]

    updated = client.put(
        f"/v1/portfolio/holdings/{holding_id}",
        headers=headers,
        json={"quantity": 3},
    )
    assert updated.status_code == 200
    assert updated.json()["items"][0]["quantity"] == 3

    deleted = client.delete(f"/v1/portfolio/holdings/{holding_id}", headers=headers)
    assert deleted.status_code == 200
    assert deleted.json()["count"] == 0


def test_portfolio_sync_replaces_positions(client, auth_env):
    token = _register(client, email="sync@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    sync = client.post(
        "/v1/portfolio/holdings/sync",
        headers=headers,
        json={
            "items": [
                {
                    "symbol": "MSFT",
                    "name": "Microsoft",
                    "quantity": 1,
                    "average_price": 300,
                    "current_price": 310,
                    "currency": "usd",
                },
                {
                    "symbol": "NVDA",
                    "name": "NVIDIA",
                    "quantity": 4,
                    "average_price": 90,
                    "current_price": 120,
                    "currency": "usd",
                },
            ]
        },
    )
    assert sync.status_code == 200
    assert sync.json()["count"] == 2

    resync = client.post(
        "/v1/portfolio/holdings/sync",
        headers=headers,
        json={
            "items": [
                {
                    "symbol": "AAPL",
                    "name": "Apple",
                    "quantity": 1,
                    "average_price": 200,
                    "current_price": 210,
                    "currency": "usd",
                }
            ]
        },
    )
    assert resync.status_code == 200
    symbols = {item["symbol"] for item in resync.json()["items"]}
    assert symbols == {"AAPL"}


def test_portfolio_sync_preserves_server_quote_when_client_sends_zero(client, auth_env):
    token = _register(client, email="preserve@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    created = client.post(
        "/v1/portfolio/holdings",
        headers=headers,
        json={
            "symbol": "AAPL",
            "name": "Apple Inc",
            "quantity": 1,
            "average_price": 150.0,
            "current_price": 307.34,
            "change_percent": -1.25,
            "currency": "usd",
            "category": "stocks",
        },
    )
    assert created.status_code == 200

    synced = client.post(
        "/v1/portfolio/holdings/sync",
        headers=headers,
        json={
            "items": [
                {
                    "symbol": "AAPL",
                    "name": "Apple Inc",
                    "quantity": 1,
                    "average_price": 150.0,
                    "current_price": 0,
                    "change_percent": 0,
                    "currency": "usd",
                    "category": "stocks",
                }
            ]
        },
    )
    assert synced.status_code == 200
    item = synced.json()["items"][0]
    assert item["current_price"] == 307.34
    assert item["change_percent"] == -1.25


def test_patch_me_updates_display_name(client, auth_env):
    token = _register(client, email="patch@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    patched = client.patch(
        "/v1/auth/me",
        headers=headers,
        json={"name": "Novo Nome"},
    )
    assert patched.status_code == 200
    assert patched.json()["name"] == "Novo Nome"
