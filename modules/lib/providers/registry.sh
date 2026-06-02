#!/usr/bin/env bash
# registry.sh - Provider registry and dispatch
# Part of Bashgency

if [ -n "${__BASHGENCY_REGISTRY_LOADED:-}" ]; then
    return 0
fi

__BASHGENCY_PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

source "$__BASHGENCY_PROVIDER_DIR/openai_compat.sh"
source "$__BASHGENCY_PROVIDER_DIR/anthropic.sh"
source "$__BASHGENCY_PROVIDER_DIR/gemini.sh"

__bashgency_provider_normalize_id() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r'
}

__bashgency_provider_is_valid() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek|openai|anthropic|gemini) return 0 ;;
        *) return 1 ;;
    esac
}

__bashgency_provider_list() {
    printf '%s\n' deepseek openai anthropic gemini
}

__bashgency_provider_list_display() {
    printf '  %-12s %-20s %-22s %s\n' "ID" "KEY (env)" "DEFAULT MODEL" "FAMILY"
    printf '  %-12s %-20s %-22s %s\n' "----" "---------" "-------------" "------"
    printf '  %-12s %-20s %-22s %s\n' "deepseek" "DEEPSEEK_API_KEY" "deepseek-chat" "openai_compat"
    printf '  %-12s %-20s %-22s %s\n' "openai" "OPENAI_API_KEY" "gpt-4o-mini" "openai_compat"
    printf '  %-12s %-20s %-22s %s\n' "anthropic" "ANTHROPIC_API_KEY" "claude-3-5-haiku-latest" "anthropic"
    printf '  %-12s %-20s %-22s %s\n' "gemini" "GEMINI_API_KEY" "gemini-2.0-flash" "gemini"
}

__bashgency_provider_resolve() {
    local id
    id="$(__bashgency_provider_normalize_id "${1:-}")"

    if [ -z "$id" ]; then
        if [ -n "${BASHGENCY_PROVIDER:-}" ]; then
            id="$(__bashgency_provider_normalize_id "$BASHGENCY_PROVIDER")"
        elif [ -n "${DEEPSEEK_API_KEY:-}" ]; then
            id="deepseek"
        else
            id="deepseek"
        fi
    fi

    if ! __bashgency_provider_is_valid "$id"; then
        return 1
    fi

    printf '%s' "$id"
}

__bashgency_provider_family() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek|openai) printf '%s' openai_compat ;;
        anthropic) printf '%s' anthropic ;;
        gemini) printf '%s' gemini ;;
        *) return 1 ;;
    esac
}

__bashgency_provider_key_var() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek) printf '%s' DEEPSEEK_API_KEY ;;
        openai) printf '%s' OPENAI_API_KEY ;;
        anthropic) printf '%s' ANTHROPIC_API_KEY ;;
        gemini) printf '%s' GEMINI_API_KEY ;;
        *) return 1 ;;
    esac
}

__bashgency_provider_default_model() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek) printf '%s' deepseek-chat ;;
        openai) printf '%s' gpt-4o-mini ;;
        anthropic) printf '%s' claude-3-5-haiku-latest ;;
        gemini) printf '%s' gemini-2.0-flash ;;
        *) return 1 ;;
    esac
}

__bashgency_provider_display_name() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek) printf '%s' DeepSeek ;;
        openai) printf '%s' OpenAI ;;
        anthropic) printf '%s' Anthropic ;;
        gemini) printf '%s' "Google Gemini" ;;
        *) printf '%s' "$1" ;;
    esac
}

__bashgency_provider_key_hint() {
    case "$(__bashgency_provider_normalize_id "$1")" in
        deepseek) printf '%s' 'sk-...' ;;
        openai) printf '%s' 'sk-...' ;;
        anthropic) printf '%s' 'sk-ant-...' ;;
        gemini) printf '%s' 'AIza...' ;;
        *) printf '%s' 'api-key' ;;
    esac
}

__bashgency_provider_validate() {
    local id="$1"
    local key_var key_val

    if ! __bashgency_provider_is_valid "$id"; then
        echo "${F_RED}${BOLD}[ ERROR ]${RESET} Unknown provider: ${F_YELLOW}${id}${RESET}"
        echo "  Available: $(__bashgency_provider_list | paste -sd ', ' -)"
        return 1
    fi

    key_var=$(__bashgency_provider_key_var "$id")
    key_val=$(__bashgency_var_indirect "$key_var")

    if [ -z "$key_val" ] \
        || [ "$key_val" = "sk-your-key-here" ] \
        || [ "$key_val" = "sk-ant-your-key-here" ] \
        || [ "$key_val" = "AIza-your-key-here" ]; then
        local env_path
        env_path="$(__bashgency_env_path)"
        printf '%s\n' "${F_RED}${BOLD}[ ERROR ]${RESET} ${F_YELLOW}${key_var}${RESET} not set in ${F_YELLOW}${env_path}${RESET}"
        printf '%s\n' "  Active provider: ${F_CYAN}${id}${RESET} ($(__bashgency_provider_display_name "$id"))"
        printf '%s\n' "  Expected format: $(__bashgency_provider_key_hint "$id")"
        return 1
    fi

    return 0
}

__bashgency_provider_set_active() {
    local id
    id="$(__bashgency_provider_resolve "${1:-}")" || return 1
    BASHGENCY_ACTIVE_PROVIDER="$id"
    export BASHGENCY_ACTIVE_PROVIDER
    printf '%s' "$id"
}

__bashgency_provider_chat() {
    local provider_id="$1"
    local system_prompt="$2"
    local user_prompt="$3"
    local model="$4"
    local family

    family=$(__bashgency_provider_family "$provider_id") || return 1

    case "$family" in
        openai_compat)
            __bashgency_openai_compat_chat "$provider_id" "$system_prompt" "$user_prompt" "$model"
            ;;
        anthropic)
            __bashgency_anthropic_chat "$system_prompt" "$user_prompt" "$model"
            ;;
        gemini)
            __bashgency_gemini_chat "$system_prompt" "$user_prompt" "$model"
            ;;
        *)
            return 1
            ;;
    esac
}

__BASHGENCY_REGISTRY_LOADED=1
