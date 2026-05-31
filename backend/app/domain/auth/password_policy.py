import re

_PASSWORD_MIN_LENGTH = 8

_RULES: tuple[tuple[str, str], ...] = (
    (r".{8,}", "mínimo 8 caracteres"),
    (r"[A-Z]", "pelo menos 1 letra maiúscula"),
    (r"\d", "1 número"),
    (r"[^A-Za-z0-9]", "1 caractere especial"),
)


def password_policy_errors(password: str) -> list[str]:
    return [message for pattern, message in _RULES if not re.search(pattern, password)]


def validate_password_strength(password: str) -> None:
    errors = password_policy_errors(password)
    if errors:
        raise ValueError(
            "Senha fraca: " + ", ".join(errors)
        )
