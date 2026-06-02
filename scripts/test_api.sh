#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${BASHGENCY_ENV:-$HOME/.config/bashgency/env}"
PROVIDER_ARG="${1:-}"

if [ ! -f "$ENV_FILE" ]; then
    echo "[ERROR] $ENV_FILE not found. Run install.sh first."
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"
source "$ROOT/modules/lib/colors.sh"
source "$ROOT/modules/lib/core.sh"
source "$ROOT/modules/lib/providers/registry.sh"
source "$ROOT/modules/lib/parser.sh"

provider=""
if [ -n "$PROVIDER_ARG" ]; then
    provider=$(__bashgency_provider_resolve "$PROVIDER_ARG") || {
        echo "[ERROR] Unknown provider: $PROVIDER_ARG"
        echo "Available: $(__bashgency_provider_list | paste -sd ', ' -)"
        exit 1
    }
    __bashgency_provider_set_active "$provider" >/dev/null
else
    provider=$(__bashgency_provider_resolve "${BASHGENCY_PROVIDER:-}") || {
        echo "[ERROR] Could not resolve provider. Set BASHGENCY_PROVIDER in $ENV_FILE"
        exit 1
    }
    __bashgency_provider_validate "$provider" || exit 1
    __bashgency_provider_set_active "$provider" >/dev/null
fi

model=$(__bashgency_provider_default_model "$provider")
key_var=$(__bashgency_provider_key_var "$provider")
key_val=$(__bashgency_var_indirect "$key_var")

echo "[*] Provider: $provider"
echo "[*] Model:    $model"
echo "[*] Key var:  $key_var (length ${#key_val})"

response=$(__bashgency_provider_chat "$provider" "You are a test assistant." "Reply with exactly: ok" "$model")
http_code=$(printf '%s' "$response" | tail -n1 | tr -d '[:space:]')
body=$(printf '%s' "$response" | sed '$d')

echo "=== HTTP_CODE: $http_code ==="
echo "=== BODY (first 1500 chars) ==="
printf '%s' "$body" | head -c 1500
echo ""
echo "=== EXTRACTED CONTENT ==="
content=$(__bashgency_extract_content "$body")
printf '%s\n' "$content"
echo "=== END ==="

[ "$http_code" = "200" ] || exit 1
[ -n "$content" ] || exit 1
