#!/usr/bin/env bash
# gemini.sh - Google Gemini generateContent API
# Part of Bashgency

if [ -n "${__BASHGENCY_GEMINI_LOADED:-}" ]; then
    return 0
fi

__BASHGENCY_GEMINI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$__BASHGENCY_GEMINI_DIR/http.sh"

__bashgency_gemini_chat() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="$3"
    local url json_body

    [ -n "${GEMINI_API_KEY:-}" ] || return 1

    url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}"

    json_body=$(cat <<EOF
{
    "systemInstruction": {
        "parts": [{"text": $(printf '%s' "$system_prompt" | jq -Rs .)}]
    },
    "contents": [
        {
            "role": "user",
            "parts": [{"text": $(printf '%s' "$user_prompt" | jq -Rs .)}]
        }
    ],
    "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 2000
    }
}
EOF
    )

    local http_headers
    http_headers=$(printf '%s\n' "Content-Type: application/json")
    __bashgency_curl_post_json "$url" "$http_headers" "$json_body"
}

__BASHGENCY_GEMINI_LOADED=1
