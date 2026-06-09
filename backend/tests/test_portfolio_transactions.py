from datetime import date


def _register(client, *, email: str = "tx@example.com"):
    response = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": "Senha-forte123!",
            "name": "Transactions Test",
        },
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def _buy(client, headers, *, symbol="AAPL", quantity=10, price=150.0, tx_date=None):
    return client.post(
        "/v1/portfolio/transactions",
        headers=headers,
        json={
            "symbol": symbol,
            "name": "Apple Inc",
            "transaction_type": "buy",
            "date": (tx_date or date(2025, 6, 1)).isoformat(),
            "quantity": quantity,
            "price_per_unit": price,
            "fees": 0,
            "currency": "usd",
            "category": "stocks",
        },
    )


def _sell(client, headers, *, symbol="AAPL", quantity=4, price=160.0, tx_date=None):
    return client.post(
        "/v1/portfolio/transactions",
        headers=headers,
        json={
            "symbol": symbol,
            "name": "Apple Inc",
            "transaction_type": "sell",
            "date": (tx_date or date(2025, 6, 2)).isoformat(),
            "quantity": quantity,
            "price_per_unit": price,
            "fees": 0,
            "currency": "usd",
            "category": "stocks",
        },
    )


def test_add_buy_transaction_creates_holding(client, auth_env):
    token = _register(client, email="buy1@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    response = _buy(client, headers, quantity=10, price=150.0)
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    holding = body["items"][0]
    assert holding["symbol"] == "AAPL"
    assert holding["quantity"] == 10
    assert holding["average_price"] == 150.0


def test_add_second_buy_recalculates_average(client, auth_env):
    token = _register(client, email="buy2@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    first = _buy(client, headers, quantity=10, price=150.0, tx_date=date(2025, 6, 1))
    assert first.status_code == 200
    second = _buy(client, headers, quantity=5, price=180.0, tx_date=date(2025, 6, 2))
    assert second.status_code == 200

    holding = second.json()["items"][0]
    assert holding["quantity"] == 15
    assert holding["average_price"] == 160.0


def test_sell_reduces_quantity(client, auth_env):
    token = _register(client, email="sell1@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    assert _buy(client, headers, quantity=10, price=150.0).status_code == 200
    sold = _sell(client, headers, quantity=4, price=160.0)
    assert sold.status_code == 200

    holding = sold.json()["items"][0]
    assert holding["quantity"] == 6
    assert holding["average_price"] == 150.0


def test_sell_all_removes_holding(client, auth_env):
    token = _register(client, email="sellall@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    assert _buy(client, headers, quantity=10, price=150.0).status_code == 200
    sold = _sell(client, headers, quantity=10, price=160.0)
    assert sold.status_code == 200
    assert sold.json()["count"] == 0

    empty = client.get("/v1/portfolio/holdings", headers=headers)
    assert empty.status_code == 200
    assert empty.json()["count"] == 0


def test_delete_transaction_recalculates(client, auth_env):
    token = _register(client, email="delete@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    assert _buy(client, headers, quantity=10, price=150.0, tx_date=date(2025, 6, 1)).status_code == 200
    assert _buy(client, headers, quantity=5, price=180.0, tx_date=date(2025, 6, 2)).status_code == 200

    listed = client.get("/v1/portfolio/transactions?symbol=AAPL", headers=headers)
    assert listed.status_code == 200
    txs = listed.json()["items"]
    assert len(txs) == 2
    second_id = txs[0]["id"] if txs[0]["quantity"] == 5 else txs[1]["id"]

    deleted = client.delete(f"/v1/portfolio/transactions/{second_id}", headers=headers)
    assert deleted.status_code == 200
    holding = deleted.json()["items"][0]
    assert holding["quantity"] == 10
    assert holding["average_price"] == 150.0


def test_list_transactions_by_symbol(client, auth_env):
    token = _register(client, email="list@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    assert _buy(client, headers, symbol="AAPL").status_code == 200
    assert _buy(
        client,
        headers,
        symbol="TSLA",
        quantity=2,
        price=250.0,
        tx_date=date(2025, 6, 3),
    ).status_code == 200

    response = client.get("/v1/portfolio/transactions?symbol=AAPL", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["items"][0]["symbol"] == "AAPL"
