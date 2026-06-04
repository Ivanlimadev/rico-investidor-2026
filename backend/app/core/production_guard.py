from app.config import settings


def validate_production_settings() -> None:
    if not settings.is_production:
        return

    errors: list[str] = []
    secret = settings.auth_secret.strip()
    if len(secret) < 32:
        errors.append("AUTH_SECRET deve ter pelo menos 32 caracteres em produção")
    if settings.docs_enabled:
        errors.append("DOCS_ENABLED deve ser false em produção")
    if not settings.open_finance_api_key.strip():
        errors.append("OPEN_FINANCE_API_KEY é obrigatória em produção")

    if errors:
        raise RuntimeError("Configuração de produção inválida: " + "; ".join(errors))
