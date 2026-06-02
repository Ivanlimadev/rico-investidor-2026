# Checklist de deploy — Rico Investidor

Use antes de publicar backend ou build de release do app.

## Backend (API)

1. Copie `backend/.env.example` para `~/Secrets/ricoapp1/.env` (ou `backend/.env`) — **nunca commitar**.
2. Defina chaves de upstream: `BRAPI_API_KEY`, `MARKETSTACK_API_KEY` (e `FMP_API_KEY` se usar).
3. Segurança obrigatória em produção:
   - `AUTH_SECRET` — segredo forte com **≥ 32 caracteres**
   - `DOCS_ENABLED=false` — esconde `/docs`, `/redoc` e `/openapi.json`
   - `AUTH_RATE_LIMIT_PER_MINUTE=10` (ou valor desejado)
4. Opcional: `OPEN_FINANCE_API_KEY` se expuser rotas Pluggy.
5. Servir a API com **HTTPS** (reverse proxy: nginx, Caddy, etc.).
6. Confirmar saúde: `GET /health` → `200`.
7. Confirmar docs desligadas: `GET /docs` → `404`.

## App mobile (release)

1. Build com URL HTTPS da API:
   ```bash
   flutter build apk --dart-define=API_BASE_URL=https://api.seudominio.com
   ```
   (idem para `ipa`, `appbundle`, etc.)
2. Release **exige** `API_BASE_URL` com HTTPS — build falha sem isso.
3. Testar login, home, cotações e carteira contra a API de produção.

## Pós-deploy (smoke test)

- [ ] App abre e carrega home sem erro de rede
- [ ] Login/registro funcionam
- [ ] Token expirado renova sessão (401 → retry)
- [ ] Carteira persiste após fechar o app
- [ ] Rate limit de auth responde 429 após abuso (opcional)

## CI

Cada push/PR em `main` roda `pytest` (backend) e `flutter test` + `flutter analyze` (mobile) via GitHub Actions.
