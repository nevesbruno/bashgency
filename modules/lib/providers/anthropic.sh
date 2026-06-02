#!/usr/bin/env bash
# anthropic.sh - Anthropic Messages API
# Part of Bashgency

if [ -n "${__BASHGENCY_ANTHROPIC_LOADED:-}" ]; then
    return 0
fi

__BASHGENCY_ANTHROPIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$__BASHGENCY_ANTHROPIC_DIR/http.sh"

__bashgency_anthropic_chat() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="$3"
    local json_body

    [ -n "${ANTHROPIC_API_KEY:-}" ] || return 1

    json_body=$(cat <<EOF
{
    "model": "$model",
    "max_tokens": 2000,
    "system": $(printf '%s' "$system_prompt" | jq -Rs .),
    "messages": [
        {"role": "user", "content": $(printf '%s' "$user_prompt" | jq -Rs .)}
    ]
}
EOF
    )

    local http_headers
    http_headers=$(printf '%s\n' \
        "Content-Type: application/json" \
        "x-api-key: $ANTHROPIC_API_KEY" \
        "anthropic-version: 2023-06-01")
    __bashgency_curl_post_json "https://api.anthropic.com/v1/messages" "$http_headers" "$json_body"
}

__BASHGENCY_ANTHROPIC_LOADED=1
