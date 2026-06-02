#!/usr/bin/env bash
# parser.sh - AI output parsing (field extraction, content extraction)
# Part of Bashgency

if [ -n "${__BASHGENCY_PARSER_LOADED:-}" ]; then
    return 0
fi

# Extract field N from "TYPE :: name :: code" format
__bashgency_parse_field() {
    local line="$1"
    local field="$2"
    echo "$line" | sed 's/ :: /\n/g' | sed -n "${field}p"
}

# Extract type (first word before " :: ")
__bashgency_parse_type() {
    local line="$1"
    echo "$line" | sed 's/ :: .*//'
}

# Sanitize JSON body - strip non-JSON prefix
__bashgency_sanitize_json_body() {
    local body="$1"
    local start
    start=$(printf '%s' "$body" | grep -bo '{' | head -1 | cut -d: -f1)
    if [ -n "$start" ] && [ "$start" -gt 0 ] 2>/dev/null; then
        body="${body:$start}"
    fi
    printf '%s' "$body"
}

__bashgency_extract_content_jq() {
    local body="$1"
    local family="$2"

    case "$family" in
        anthropic)
            printf '%s' "$body" | jq -r '.content[0].text // empty' 2>/dev/null
            ;;
        gemini)
            printf '%s' "$body" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null
            ;;
        openai_compat|*)
            printf '%s' "$body" | jq -r '
                .choices[0].message.content //
                .choices[0].delta.content //
                .response //
                .message.content //
                empty
            ' 2>/dev/null
            ;;
    esac
}

# Extract AI content from API response JSON
__bashgency_extract_content() {
    local body="$1"
    local ai_content=""
    local family="openai_compat"

    body=$(__bashgency_sanitize_json_body "$body")

    if [ -n "${BASHGENCY_ACTIVE_PROVIDER:-}" ]; then
        family=$(__bashgency_provider_family "$BASHGENCY_ACTIVE_PROVIDER")
        family="${family:-openai_compat}"
    fi

    ai_content=$(__bashgency_extract_content_jq "$body" "$family")

    if [ -n "$ai_content" ]; then
        printf '%s' "$ai_content"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        ai_content=$(printf '%s' "$body" | BASHGENCY_PROVIDER_FAMILY="$family" python3 -c "
import json, os, re, sys

family = os.environ.get('BASHGENCY_PROVIDER_FAMILY', 'openai_compat')
raw = sys.stdin.read().strip()
idx = raw.find('{')
if idx > 0:
    raw = raw[idx:]
data = None
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    try:
        data, _ = json.JSONDecoder().raw_decode(raw)
    except Exception:
        pass
if data:
    if family == 'anthropic':
        content = ((data.get('content') or [{}])[0].get('text') or '')
        if content:
            sys.stdout.write(content)
            sys.exit(0)
    elif family == 'gemini':
        parts = (((data.get('candidates') or [{}])[0].get('content') or {}).get('parts') or [{}])
        content = parts[0].get('text') or ''
        if content:
            sys.stdout.write(content)
            sys.exit(0)
    else:
        choices = data.get('choices') or []
        if choices:
            msg = choices[0].get('message') or {}
            content = msg.get('content') or ''
            if content:
                sys.stdout.write(content)
                sys.exit(0)
for marker in ('FUNCTION ::', 'ALIAS ::', 'MODULE ::'):
    pos = raw.find(marker)
    if pos < 0:
        continue
    chunk = raw[pos:]
    for end in ('\",\"logprobs\"', '\",\"finish_reason\"', '\"},\"logprobs\"'):
        e = chunk.find(end)
        if e > 0:
            chunk = chunk[:e]
            break
    else:
        chunk = re.sub(r'\"[}\]]+$', '', chunk)
    chunk = chunk.replace('\\\\n', chr(10)).replace('\\\\\"', '\"').replace('\\\\\\\\', '\\\\')
    sys.stdout.write(chunk)
    sys.exit(0)
" 2>/dev/null)
    fi

    if [ -n "$ai_content" ]; then
        printf '%s' "$ai_content"
        return 0
    fi

    return 1
}

__BASHGENCY_PARSER_LOADED=1
