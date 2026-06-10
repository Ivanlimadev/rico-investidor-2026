from __future__ import annotations

from functools import lru_cache

import plaid
from plaid.api import plaid_api
from plaid.model.country_code import CountryCode
from plaid.model.accounts_get_request import AccountsGetRequest
from plaid.model.institutions_get_by_id_request import InstitutionsGetByIdRequest
from plaid.model.item_get_request import ItemGetRequest
from plaid.model.item_remove_request import ItemRemoveRequest
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.transactions_sync_request import TransactionsSyncRequest

from app.config import settings
from app.core.exceptions import AppError


def plaid_is_configured() -> bool:
    return bool(settings.plaid_client_id.strip() and settings.plaid_secret.strip())


def _plaid_env() -> plaid.Environment:
    env = settings.plaid_env.strip().lower()
    if env == "production":
        return plaid.Environment.Production
    if env == "development":
        return plaid.Environment.Development
    return plaid.Environment.Sandbox


@lru_cache(maxsize=1)
def get_plaid_client() -> plaid_api.PlaidApi:
    if not plaid_is_configured():
        raise AppError("Plaid não configurado", status_code=503)
    configuration = plaid.Configuration(
        host=_plaid_env(),
        api_key={
            "clientId": settings.plaid_client_id.strip(),
            "secret": settings.plaid_secret.strip(),
        },
    )
    api_client = plaid.ApiClient(configuration)
    return plaid_api.PlaidApi(api_client)


def _products() -> list[Products]:
    raw = settings.plaid_products.strip() or "transactions"
    items: list[Products] = []
    for part in raw.split(","):
        name = part.strip().lower()
        if name == "transactions":
            items.append(Products("transactions"))
    return items or [Products("transactions")]


def _country_codes() -> list[CountryCode]:
    raw = settings.plaid_country_codes.strip() or "US"
    return [CountryCode(code.strip()) for code in raw.split(",") if code.strip()]


class PlaidGateway:
    def create_link_token(self, *, user_id: str) -> str:
        client = get_plaid_client()
        request = LinkTokenCreateRequest(
            user=LinkTokenCreateRequestUser(client_user_id=user_id),
            client_name="Rico Investidor",
            products=_products(),
            country_codes=_country_codes(),
            language="en",
        )
        response = client.link_token_create(request)
        return response["link_token"]

    def exchange_public_token(self, public_token: str) -> tuple[str, str]:
        client = get_plaid_client()
        request = ItemPublicTokenExchangeRequest(public_token=public_token)
        response = client.item_public_token_exchange(request)
        return response["access_token"], response["item_id"]

    def sync_transactions(self, access_token: str, cursor: str | None) -> dict:
        client = get_plaid_client()
        request = TransactionsSyncRequest(access_token=access_token, cursor=cursor)
        response = client.transactions_sync(request)
        return response.to_dict()

    def fetch_item(self, access_token: str) -> dict:
        client = get_plaid_client()
        request = ItemGetRequest(access_token=access_token)
        response = client.item_get(request)
        return response.to_dict()

    def fetch_accounts(self, access_token: str) -> dict:
        client = get_plaid_client()
        request = AccountsGetRequest(access_token=access_token)
        response = client.accounts_get(request)
        return response.to_dict()

    def remove_item(self, access_token: str) -> None:
        client = get_plaid_client()
        request = ItemRemoveRequest(access_token=access_token)
        client.item_remove(request)

    def fetch_institution(self, institution_id: str) -> dict:
        client = get_plaid_client()
        request = InstitutionsGetByIdRequest(
            institution_id=institution_id,
            country_codes=_country_codes(),
        )
        response = client.institutions_get_by_id(request)
        return response.to_dict()
