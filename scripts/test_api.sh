#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${AI_ALIAS_ENV:-$HOME/.config/ai-alias/env}"
if [ ! -f "$ENV_FILE" ]; then
    echo "[ERRO] $ENV_FILE nao encontrado. Rode install.sh primeiro."
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo "[ERRO] DEEPSEEK_API_KEY nao definida em $ENV_FILE"
    exit 1
fi

echo "Key length: ${#DEEPSEEK_API_KEY}"

BODY=$(curl -m 20 -s -w "\n%{http_code}" \
  https://api.deepseek.com/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"say hi"}],"max_tokens":30}' 2>&1)

HTTP_CODE=$(echo "$BODY" | tail -n1)
CONTENT=$(echo "$BODY" | sed '$d')

echo "=== HTTP_CODE: $HTTP_CODE ==="
echo "=== BODY (first 1500 chars) ==="
echo "$CONTENT" | head -c 1500
echo ""
echo "=== JQ TEST ==="
echo "$CONTENT" | jq -r '.choices[0].message.content // "NULL"' 2>&1
echo "=== END ==="

[ "$HTTP_CODE" = "200" ] || exit 1
