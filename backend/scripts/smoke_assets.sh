#!/usr/bin/env bash
# Smoke test rápido para GET /v1/assets/{ticker}
# Uso: ./scripts/smoke_assets.sh [base_url]

set -euo pipefail

BASE="${1:-http://127.0.0.1:8000}"

echo "== health =="
curl -fsS "$BASE/health" | python3 -m json.tool

check() {
  local ticker="$1"
  echo ""
  echo "== $ticker =="
  curl -fsS "$BASE/v1/assets/$ticker" | python3 -c "
import json, sys
d = json.load(sys.stdin)
stock = d.get('stock') or {}
quote = stock.get('quote') or {}
print(f\"ticker={d.get('ticker')} kind={d.get('kind')} category={d.get('category')}\")
print(f\"price={quote.get('price')} candles={len(stock.get('candles') or [])}\")
print(f\"sections={d.get('sections')}\")
for note in d.get('notes') or []:
    print(f'note: {note}')
"
}

check PETR4
check BOVA11
check MXRF11

echo ""
echo "OK — smoke test concluído"
