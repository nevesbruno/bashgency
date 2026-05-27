#!/usr/bin/env bash
# api.sh - DeepSeek API interaction
# Part of Bashgency

if [ -n "${__BASHGENCY_API_LOADED:-}" ]; then
    return 0
fi

# Build the system prompt for DeepSeek
__bashgency_build_system_prompt() {
    cat << 'SYSTEM'
You are Bashgency, a Shell Script (bash/zsh) specialist. You create aliases, functions, and shell modules.

## ABSOLUTE RULES:
1. Generate ONLY valid shell code. NO markdown, NO explanations, NO code fences.
2. Output must be PURE executable code.
3. Simple aliases: use `alias name="command"`.
4. Functions: use `function name(){ ... }`.
5. For complex commands (>3 lines or heavy logic), create a SEPARATE FILE in ~/.config/bashgency/modules/ and add a source line.

## OUTPUT FORMAT:
Each line must start with a marker using DUAL COLONS as separator:
- For ALIAS:  "ALIAS :: alias_name :: command"
- For FUNCTION (inline): "FUNCTION :: function_name :: function_code"
- For MODULE (separate file): "MODULE :: module_name :: file_content :: source_command"

IMPORTANT: Use exactly " :: " (space-colon-colon-space) as the separator.

## CONVENTIONS:
- Git aliases: prefix `g`
- Docker aliases: prefix `d`
- Npm aliases: prefix `n`
- Project aliases: descriptive name, no prefix
- Internal utility functions: prefix `__`

## EXAMPLES (prompt: "colorful diff alias with stat"):
ALIAS :: gdiffc :: git diff --stat --color=always | less -R

## EXAMPLE FUNCTION (prompt: "create branch with date"):
FUNCTION :: branch-date :: function branch-date() {
    local branch_name="${1:-feature}"
    local date_suffix
    date_suffix=$(date +"%Y%m%d")
    git checkout -b "${branch_name}-${date_suffix}"
    echo "Branch created: ${branch_name}-${date_suffix}"
}

## EXAMPLE MODULE (prompt: "complex deploy function"):
MODULE :: deploy :: function deploy() {
    local env="${1:-production}"
    echo "Deploying to $env..."
    git pull origin main
    npm run build
    npm run test
    echo "Deploy completed for $env!"
} :: source ~/.config/bashgency/modules/deploy.sh

## IMPORTANT:
- Always use 'function' keyword
- Include basic validation (check if arguments were passed)
- Return functional, idiomatic shell code
SYSTEM
}

# Extract context from existing aliases file for style reference
__bashgency_build_context() {
    local script_path
    script_path="$(__bashgency_aliases_path)"
    if [ -f "$script_path" ]; then
        head -150 "$script_path" 2>/dev/null | grep -E "^(function|alias)" | head -20
    fi
}

# Generic API call - takes explicit system and user prompts
__bashgency_call_api_raw() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-deepseek-chat}"

    __bashgency_load_env || return 1

    local tmp_out
    tmp_out=$(mktemp)

    curl -s -w "\n%{http_code}" https://api.deepseek.com/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        -d "$(cat <<EOF
{
    "model": "$model",
    "stream": false,
    "messages": [
        {"role": "system", "content": $(echo "$system_prompt" | jq -Rs .)},
        {"role": "user", "content": $(echo "$user_prompt" | jq -Rs .)}
    ],
    "temperature": 0.3,
    "max_tokens": 2000
}
EOF
        )" > "$tmp_out" 2>/dev/null

    local response
    response=$(cat "$tmp_out")
    rm -f "$tmp_out"
    printf '%s' "$response"
}

# Call DeepSeek API for alias/function/module generation
__bashgency_call_api() {
    local prompt="$1"
    local model="${2:-deepseek-chat}"

    local system_prompt
    system_prompt=$(__bashgency_build_system_prompt)

    local context
    context=$(__bashgency_build_context)

    local user_prompt
    user_prompt=$(printf 'Create alias/function based on this description: %s\n\nExisting aliases in the file (style reference):\n%s' "$prompt" "$context")

    __bashgency_call_api_raw "$system_prompt" "$user_prompt" "$model"
}

# Parse HTTP response into (http_code, body)
__bashgency_parse_http_response() {
    local response="$1"
    local http_code body

    http_code=$(printf '%s\n' "$response" | tail -n1 | tr -d '[:space:]')
    if [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
        body=$(printf '%s\n' "$response" | sed '$d')
    else
        http_code="${response: -3}"
        body="${response:0:${#response}-3}"
    fi

    printf '%s\n%s' "$http_code" "$body"
}

__BASHGENCY_API_LOADED=1
