#!/usr/bin/env bash
# api.sh - AI provider prompts and chat delegation
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
    local model="${3:-}"
    local provider_override="${4:-}"
    local provider=""

    __bashgency_load_env "$provider_override" || return 1

    provider="${BASHGENCY_ACTIVE_PROVIDER:-}"
    if [ -z "$provider" ]; then
        provider=$(__bashgency_provider_resolve "${BASHGENCY_PROVIDER:-}") || return 1
    fi

    if [ -z "$model" ]; then
        model=$(__bashgency_provider_default_model "$provider")
    fi

    __bashgency_provider_chat "$provider" "$system_prompt" "$user_prompt" "$model"
}

# Minimal live API ping (validates HTTP layer + credentials)
__bashgency_verify_provider_api() {
    local provider="${1:-${BASHGENCY_ACTIVE_PROVIDER:-}}"
    local model response code

    [ -n "$provider" ] || return 1
    __bashgency_load_env "$provider" || return 1
    model=$(__bashgency_provider_default_model "$provider")
    response=$(__bashgency_provider_chat "$provider" "You are a test assistant." "Reply with exactly: ok" "$model")
    code=$(printf '%s' "$response" | tail -n1 | tr -d '[:space:]')
    [ "$code" = "200" ]
}

# Call active provider for alias/function/module generation
__bashgency_call_api() {
    local prompt="$1"
    local model="${2:-}"
    local provider_override="${3:-}"

    local system_prompt
    system_prompt=$(__bashgency_build_system_prompt)

    local context
    context=$(__bashgency_build_context)

    local user_prompt
    user_prompt=$(printf 'Create alias/function based on this description: %s\n\nExisting aliases in the file (style reference):\n%s' "$prompt" "$context")

    __bashgency_call_api_raw "$system_prompt" "$user_prompt" "$model" "$provider_override"
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
