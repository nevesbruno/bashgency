#!/usr/bin/env bash
# http.sh - Shared HTTP helpers for AI providers
# Part of Bashgency

if [ -n "${__BASHGENCY_HTTP_LOADED:-}" ]; then
    return 0
fi

# POST JSON; returns response body + newline + http_code (curl -s -w "\n%{http_code}")
# headers_block: newline-separated "Header: value" lines (must be a string, not an array name)
__bashgency_curl_post_json() {
    local url="$1"
    local headers_block="$2"
    local json_body="$3"
    local tmp_out response h
    local -a curl_cmd=(-s -w $'\n%{http_code}')

    while IFS= read -r h || [ -n "$h" ]; do
        [ -z "$h" ] && continue
        curl_cmd+=(-H "$h")
    done <<EOF
$headers_block
EOF

    tmp_out=$(mktemp)
    curl "${curl_cmd[@]}" "$url" -d "$json_body" > "$tmp_out" 2>/dev/null
    response=$(cat "$tmp_out")
    rm -f "$tmp_out"
    printf '%s' "$response"
}

__BASHGENCY_HTTP_LOADED=1
