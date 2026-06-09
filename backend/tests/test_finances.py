def _register(client, *, email: str = "financas@example.com"):
    response = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": "Senha-forte123!",
            "name": "Finanças Teste",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def test_finances_requires_registered_user(client, auth_env):
    anon = client.post("/v1/auth/anonymous", json={"device_id": "device-fin-1"}).json()[
        "access_token"
    ]
    response = client.get(
        "/v1/finances/summary",
        headers={"Authorization": f"Bearer {anon}"},
    )
    assert response.status_code == 403


def test_finances_link_token_without_plaid_config(client, auth_env, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "plaid_client_id", "")
    monkeypatch.setattr(settings, "plaid_secret", "")
    token = _register(client, email="link@example.com")
    response = client.post(
        "/v1/finances/link-token",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 503


def test_finances_manual_transaction_and_summary(client, auth_env):
    token = _register(client, email="manual@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    created = client.post(
        "/v1/finances/transactions",
        headers=headers,
        json={
            "amount": -45.5,
            "name": "Coffee Shop",
            "merchant_name": "Blue Bottle",
            "category": "food_drink",
        },
    )
    assert created.status_code == 200
    tx_id = created.json()["id"]

    income = client.post(
        "/v1/finances/transactions",
        headers=headers,
        json={
            "amount": 3200.0,
            "name": "Paycheck",
            "category": "income",
        },
    )
    assert income.status_code == 200

    transfer = client.post(
        "/v1/finances/transactions",
        headers=headers,
        json={
            "amount": -500.0,
            "name": "Savings transfer",
            "category": "transfers",
        },
    )
    assert transfer.status_code == 200

    summary = client.get("/v1/finances/summary", headers=headers)
    assert summary.status_code == 200
    body = summary.json()
    assert body["income_mtd"] == 3200.0
    assert body["expenses_mtd"] == 45.5
    assert body["balance"] == 3154.5

    listed = client.get("/v1/finances/transactions", headers=headers)
    assert listed.status_code == 200
    assert listed.json()["count"] == 3

    patched = client.patch(
        f"/v1/finances/transactions/{tx_id}",
        headers=headers,
        json={"note": "weekend treat"},
    )
    assert patched.status_code == 200
    assert patched.json()["note"] == "weekend treat"


def test_finances_budget_flow(client, auth_env):
    token = _register(client, email="budget@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    client.post(
        "/v1/finances/transactions",
        headers=headers,
        json={"amount": -80, "name": "Groceries", "category": "food_drink"},
    )

    saved = client.put(
        "/v1/finances/budget",
        headers=headers,
        json={
            "month": "2026-06",
            "categories": [{"category": "food_drink", "limit": 500, "spent": 0}],
        },
    )
    assert saved.status_code == 200
    budget = saved.json()
    assert budget["categories"][0]["limit"] == 500
    assert budget["categories"][0]["spent"] == 80


def test_finances_webhook_is_public(client, auth_env):
    response = client.post(
        "/v1/finances/webhook",
        json={"webhook_type": "TRANSACTIONS", "webhook_code": "SYNC_UPDATES_AVAILABLE"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
