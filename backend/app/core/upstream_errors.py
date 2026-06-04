import logging

logger = logging.getLogger(__name__)


def upstream_public_message(provider: str, status_code: int) -> str:
    """Mensagem genérica para o cliente — detalhes ficam só no log."""
    return f"Falha ao consultar {provider} ({status_code})"


def log_upstream_failure(
    *,
    provider: str,
    status_code: int,
    url: str | None = None,
    body_snippet: str | None = None,
) -> None:
    snippet = (body_snippet or "")[:500]
    logger.warning(
        "upstream_error provider=%s status=%s url=%s body=%s",
        provider,
        status_code,
        url or "",
        snippet,
    )
