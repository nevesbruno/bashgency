#!/usr/bin/env bash
# openai_compat.sh - OpenAI-shaped chat/completions (deepseek, openai)
# Part of Bashgency

if [ -n "${__BASHGENCY_OPENAI_COMPAT_LOADED:-}" ]; then
    return 0
fi

__BASHGENCY_OPENAI_COMPAT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$__BASHGENCY_OPENAI_COMPAT_DIR/http.sh"

__bashgency_openai_compat_chat() {
    local provider_id="$1"
    local system_prompt="$2"
    local user_prompt="$3"
    local model="$4"

    local url key_var api_key json_body
    case "$(printf '%s' "$provider_id" | tr '[:upper:]' '[:lower:]')" in
        deepseek)
            url="https://api.deepseek.com/chat/completions"
            key_var="DEEPSEEK_API_KEY"
            ;;
        openai)
            url="https://api.openai.com/v1/chat/completions"
            key_var="OPENAI_API_KEY"
            ;;
        *)
            return 1
            ;;
    esac

    api_key=$(__bashgency_var_indirect "$key_var")
    [ -n "$api_key" ] || return 1

    json_body=$(cat <<EOF
{
    "model": "$model",
    "stream": false,
    "messages": [
        {"role": "system", "content": $(printf '%s' "$system_prompt" | jq -Rs .)},
        {"role": "user", "content": $(printf '%s' "$user_prompt" | jq -Rs .)}
    ],
    "temperature": 0.3,
    "max_tokens": 2000
}
EOF
    )

    local http_headers
    http_headers=$(printf '%s\n' \
        "Content-Type: application/json" \
        "Authorization: Bearer $api_key")
    __bashgency_curl_post_json "$url" "$http_headers" "$json_body"
}

__BASHGENCY_OPENAI_COMPAT_LOADED=1
