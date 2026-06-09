"""Categorias normalizadas do app (inspiradas no PFCv2 do Plaid)."""

from __future__ import annotations

FINANCE_CATEGORIES: dict[str, list[str]] = {
    "food_drink": ["Restaurants", "Groceries", "Coffee Shops", "Bars"],
    "shopping": ["Clothing", "Electronics", "General Merchandise"],
    "transportation": ["Gas", "Public Transit", "Rideshare", "Parking"],
    "housing": ["Rent", "Mortgage", "Utilities"],
    "health": ["Pharmacy", "Doctor", "Gym"],
    "entertainment": ["Movies", "Streaming", "Events"],
    "travel": ["Flights", "Hotels", "Car Rental"],
    "education": ["Tuition", "Books", "Courses"],
    "income": ["Salary", "Paycheck", "Bonus", "Interest"],
    "transfers": ["Transfer", "Internal Transfer"],
    "fees": ["Bank Fee", "ATM Fee", "Service Charge"],
    "other": ["Miscellaneous"],
}

PLAID_PFC_TO_CATEGORY: dict[str, str] = {
    "FOOD_AND_DRINK": "food_drink",
    "GENERAL_MERCHANDISE": "shopping",
    "TRANSPORTATION": "transportation",
    "RENT_AND_UTILITIES": "housing",
    "MEDICAL": "health",
    "ENTERTAINMENT": "entertainment",
    "TRAVEL": "travel",
    "EDUCATION": "education",
    "INCOME": "income",
    "TRANSFER_IN": "transfers",
    "TRANSFER_OUT": "transfers",
    "BANK_FEES": "fees",
}


def normalize_plaid_category(primary: str | None, detailed: str | None = None) -> tuple[str, str | None]:
    if not primary:
        return "other", detailed
    key = primary.strip().upper().replace(" ", "_")
    category = PLAID_PFC_TO_CATEGORY.get(key, "other")
    sub = detailed.strip() if detailed else None
    return category, sub
