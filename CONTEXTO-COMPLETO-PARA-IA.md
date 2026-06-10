# Rico Investidor — Contexto completo para outra IA

**Gerado em:** 10 jun 2026  
**Projeto:** `/Users/ivanlimadev/ricoapp1`  
**Repo GitHub:** https://github.com/Ivanlimadev/rico-investidor-2026.git  
**Branch:** `main` (último commit inclui alertas, legal, crypto hero, fixes segurança)

---

## 1. O QUE É O PROJETO

App de investimentos (Flutter) + API (FastAPI + Postgres).

**Foco atual:** ações americanas (US) + criptomoedas. Brasil/B3 legado, muita coisa oculta.

| Parte | Caminho |
|-------|---------|
| Backend | `/Users/ivanlimadev/ricoapp1/backend` |
| Mobile | `/Users/ivanlimadev/ricoapp1/mobile` |
| Secrets | `~/Secrets/ricoapp1/.env` (NÃO commitar) |
| Zip código | `/Users/ivanlimadev/ricoapp1-codigo-atual-20260610.zip` |

**Login teste:** `ivan@teste.com` / `Senha-forte123!`

---

## 2. COMO RODAR

### Backend
```bash
cd ~/ricoapp1/backend
source .venv/bin/activate
alembic upgrade head
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### Mobile
```bash
cd ~/ricoapp1/mobile
flutter pub get
flutter run
```

### Health
```bash
curl http://127.0.0.1:8000/health
```

---

## 3. PROBLEMA PRINCIPAL (URGENTE) — COTAÇÃO ERRADA NA CARTEIRA

### Sintoma
- **AAPL** mostra **US$ 307,34** no app (carteira / saldo total)
- Preço real de mercado (9 jun 2026): **~US$ 290,55** (fechamento, -3,64%)
- Detalhe do ativo e carteira **não batem**
- Saldo total da carteira **inconsistente**

### O que é 307,34
- Fechamento EOD **antigo** (05/06/2026 nos testes do projeto)
- **NÃO** é cotação ao vivo
- Aparece em `backend/tests/test_quote_reconcile.py` e `test_portfolio.py`

### Causa raiz (confirmada em testes locais)
1. **Marketstack retorna HTTP 403** na cotação individual:
   ```
   GET /v1/global-markets/AAPL
   → "Marketstack: recurso indisponível no plano atual"
   ```
2. **Batch também falha vazio:**
   ```
   GET /v1/global-markets/quotes?symbols=AAPL
   → { "items": [], "count": 0 }
   ```
3. App **não atualiza** `currentPrice` quando API falha — mantém valor velho salvo em:
   - `SharedPreferences` (mobile)
   - Postgres `portfolio_holdings.current_price` (se sincronizado)
4. Reconciliação EOD usa **último candle disponível** do Marketstack; se dados param em 05/06, preço fica 307,34

### Arquivos-chave para corrigir
| Arquivo | Função |
|---------|--------|
| `backend/app/services/global_market_service.py` | `get_quote`, `get_quotes_batch`, `_resolve_live_us_quote` |
| `backend/app/domain/global_markets/quote_reconcile.py` | `reconcile_quote_with_candles`, `quote_looks_stale_during_session` |
| `backend/app/clients/marketstack/client.py` | 403 → erro plano |
| `mobile/lib/services/portfolio_price_service.dart` | refresh preços carteira |
| `mobile/lib/features/portfolio/widgets/portfolio_balance_hero.dart` | saldo total exibido |
| `mobile/lib/core/utils/portfolio_balance.dart` | cálculo patrimônio |
| `mobile/lib/services/portfolio_storage.dart` | persiste preços locais |

### Correções já tentadas (podem não estar no zip que usuário tem)
- `get_quotes_batch` passou a usar mesmo pipeline que `get_quote`
- `portfolio_price_service` passou a chamar `getQuote` por símbolo (não batch)
- Home deixou de duplicar refresh de preços

### O que AINDA FALTA implementar (sugerido)
1. **Não aplicar preço EOD se candle > 2 dias** — rejeitar 307,34 quando sessão é 05/06 e hoje é 09/06
2. **Flag `quote_stale` ou `session_date`** no JSON da API → app mostra aviso "Cotação desatualizada"
3. **Não salvar `currentPrice` na carteira** quando refresh falha (hoje falha em silêncio)
4. **Fallback FMP obrigatório** quando Marketstack 403 (`FMP_API_KEY` no .env)
5. **Limpar preço** ou mostrar "—" quando API indisponível

### .env relevante
```env
MARKETSTACK_API_KEY=...
MARKETSTACK_PLAN=professional
FMP_API_KEY=...              # CRÍTICO para fallback ao vivo
AUTH_SECRET=...              # min 32 chars
DATABASE_URL=postgresql+psycopg://...
```

---

## 4. ARQUITETURA DE PREÇOS

### Ações US
| Camada | Fonte |
|--------|-------|
| Primário | Marketstack |
| Fallback ao vivo | FMP (budget 230/dia) |
| Reconciliação | `quote_reconcile.py` — EOD quando mercado fechado, FMP quando stale no pregão |

### Cripto
| Camada | Fonte |
|--------|-------|
| Primário | Binance (pode 451 regional) |
| Fallback | CoinGecko |
| Detalhe | WebSocket live + REST 24h |
| Carteira | `GET /v1/crypto/quotes?symbols=BTC,ETH` (batch) |

### Carteira — fluxo refresh
```
MainShellScreen (timer 60s)
  → PortfolioPriceService.refreshAllDetailed()
    → US: getQuote(symbol) por holding
    → Crypto: getQuotesBatch(symbols)
  → patch holding.currentPrice
  → PortfolioStorage.save()
```

### Detalhe ativo US
```
GlobalStockDetailScreen
  → QuoteRefreshTimer
  → globalMarketRepository.refreshQuote()
  → GET /v1/global-markets/{symbol}
  → UsQuoteEnrichment.reconcileQuote() (client-side com candles)
```

**Problema:** carteira e detalhe usam caminhos diferentes; quando API falha, carteira fica com cache.

---

## 5. O QUE FOI PEDIDO PARA OCULTAR (NÃO PERDER TEMPO COM ISSO)

Usuário pediu para **ocultar**, não remover código:
- Plaid / Finanças / integração bancária
- Assinatura / RevenueCat / Paywall
- Comunidade (fora do bottom nav)
- Ads tratados como plano free (`kAdsSubscriptionPlan`)

**NÃO pedir para configurar Plaid webhook** — usuário não usa.

---

## 6. O QUE JÁ FOI IMPLEMENTADO

### Backend
- Migrations até `006_price_alerts`
- Auth: login, registro, reset senha, foto perfil
- Portfolio: holdings + transações
- Crypto: Binance + CoinGecko fallback
- Global markets: reconcile EOD/FMP
- Alertas preço: `POST/GET/DELETE /v1/alerts`
- Exclusão conta: limpa Plaid, finanças, alertas, avatar
- Webhook Plaid: header `X-Rico-Webhook-Secret` (ignorar se não usa Plaid)

### Mobile
- Crypto detail: hero gradiente + gráfico azul (igual ações)
- Sino alerta preço no detalhe (substitui casinha)
- Legal in-app: termos, privacidade, sobre nós, disclaimer
- Cadastro: termos + privacidade + disclaimer investimento
- Exclusão conta: fluxo "Que pena que você vai" + limpa carteira
- AdMob: banner, native feed, interstitial
- Notificações locais: infra (`flutter_local_notifications`) — dividendos ainda não agendados

### Migration (usuário já rodou)
```
alembic current → 006_price_alerts (head)
```

---

## 7. ESTRUTURA API (v1)

| Prefixo | Auth | Uso |
|---------|------|-----|
| `/v1/auth` | parcial | login, me, delete |
| `/v1/global-markets` | JWT se AUTH_SECRET setado | ações US |
| `/v1/crypto` | JWT | cripto |
| `/v1/portfolio` | registrado | carteira |
| `/v1/alerts` | registrado | alertas preço |
| `/v1/finances` | registrado | Plaid (oculto UI) |
| `/health` | público | status upstream |

### Endpoints cotação
```
GET /v1/global-markets/AAPL          → cotação única
GET /v1/global-markets/quotes?symbols=AAPL,MSFT
GET /v1/crypto/BTC
GET /v1/crypto/quotes?symbols=BTC,ETH
```

---

## 8. TESTES

```bash
# Backend
cd backend && pytest tests/test_quote_reconcile.py tests/test_quote_stale.py -q

# Mobile
cd mobile && flutter analyze
cd mobile && flutter test
```

**Teste manual cotação:**
```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ivan@teste.com","password":"Senha-forte123!"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

curl -s http://127.0.0.1:8000/v1/global-markets/AAPL \
  -H "Authorization: Bearer $TOKEN"
```

Esperado: JSON com `"price": ~290` — **não** 403 nem 307.34

---

## 9. UI — ONDE APARECE PREÇO

| Tela | Campo |
|------|-------|
| Carteira → card ativo | `holding.currentPrice` chip "Atual" |
| Carteira → hero topo | `breakdown.internationalMarketValueUsd` |
| Detalhe ação | `_HeroQuoteCard` → `quote.price` |
| Detalhe cripto | `CryptoHeroQuoteCard` → live ou REST |
| Add asset | `_selected!.price` ao adicionar |

---

## 10. PROMPT SUGERIDO PARA OUTRA IA

```
Projeto: Rico Investidor (Flutter + FastAPI + Postgres)
Path: ~/ricoapp1

BUG CRÍTICO: AAPL mostra US$307.34 na carteira mas mercado está ~US$290.55.
- API local: GET /v1/global-markets/AAPL retorna 403 Marketstack plano
- Batch quotes retorna items vazio
- App mantém currentPrice antigo quando refresh falha
- 307.34 = EOD close de 2026-06-05 (stale)

TAREFAS (ordem):
1. Quando Marketstack 403, usar FMP fallback obrigatório em get_quote
2. Não reconciliar EOD se último candle > 2 dias úteis — marcar stale
3. portfolio_price_service: se refresh falha, NÃO manter preço velho — zerar ou flag stale
4. UI: banner "Cotação desatualizada" na carteira e holding card
5. Testes: AAPL price deve estar dentro de 1% do Yahoo/FMP

NÃO MEXER: Plaid, finanças, paywall, comunidade (ocultos por pedido do usuário)
NÃO COMMITAR: .env, secrets

Arquivos principais:
- backend/app/services/global_market_service.py
- backend/app/domain/global_markets/quote_reconcile.py
- mobile/lib/services/portfolio_price_service.dart
- mobile/lib/features/portfolio/widgets/portfolio_holding_card.dart
- mobile/lib/features/portfolio/widgets/portfolio_balance_hero.dart
```

---

## 11. ADMOB (produção)

| Plataforma | App ID |
|------------|--------|
| Android | `ca-app-pub-7113858977365190~5603278090` |
| iOS | `ca-app-pub-7113858977365190~7653353211` |

Ads sempre ativos (`kAdsSubscriptionPlan = free`).

---

## 12. LEGAL

- URLs configuradas: `https://ricoinvestidor.github.io/legal/` (404 até publicar)
- Conteúdo in-app: `mobile/lib/features/legal/legal_content.dart`
- HTML para deploy: `docs/legal/terms.html`, `privacy.html`

---

## 13. COMMITS

Usuário pediu commit+push em sessão anterior:
- Commit `f6e6b18` em `main` no GitHub
- Alterações posteriores (fix cotação batch, crypto hero, alertas) podem estar **uncommitted**

Verificar:
```bash
cd ~/ricoapp1 && git status
```

---

## 14. INVESTIDOR10 — COMPARAÇÃO (referência)

Eles têm: notificações proventos, agenda dividendos, carteira com indicadores, preço médio, gráficos comparativos.

Nós temos parcial: dividendos in-app, carteira US+crypto, sem push real ainda, sem B3 integração.

---

## 15. COMANDOS ÚTEIS

```bash
# Ver preço salvo localmente (debug)
# SharedPreferences key: portfolio holdings no app

# Reiniciar backend
pkill -f uvicorn; cd ~/ricoapp1/backend && source .venv/bin/activate && uvicorn app.main:app --reload --port 8000

# Flutter hot restart
# Tecla R no terminal flutter run

# Gerar zip de novo
cd ~/ricoapp1 && zip -r ~/ricoapp1-codigo.zip . -x "*.git/*" -x "mobile/build/*" -x "backend/.venv/*"
```

---

**FIM DO CONTEXTO — copie este arquivo inteiro para a outra IA.**
