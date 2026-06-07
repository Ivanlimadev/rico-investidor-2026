def test_cors_preflight_is_not_blocked_by_auth(client, auth_env):
    response = client.options(
        "/v1/global-markets/capabilities",
        headers={
            "Origin": "http://localhost:57665",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "http://localhost:57665"
