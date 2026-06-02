#!/usr/bin/env bash
# core.sh - Configuration paths, directory setup, env loading
# Part of Bashgency

if [ -n "${__BASHGENCY_CORE_LOADED:-}" ]; then
    return 0
fi

BASHGENCY_DIR="${BASHGENCY_DIR:-$HOME/.config/bashgency}"
BASHGENCY_ENV="$BASHGENCY_DIR/env"
BASHGENCY_HISTORY="$BASHGENCY_DIR/history"
BASHGENCY_MODULES_DIR="$BASHGENCY_DIR/modules"
BASHGENCY_BACKUP_DIR="$BASHGENCY_DIR/backups"

__bashgency_ensure_dirs() {
    mkdir -p "$BASHGENCY_DIR" "$BASHGENCY_MODULES_DIR" "$BASHGENCY_BACKUP_DIR"
}

__bashgency_load_env() {
    local provider_override="${1:-}"
    local provider=""

    __bashgency_ensure_dirs
    if [ -f "$BASHGENCY_ENV" ]; then
        # shellcheck disable=SC1090
        set -a
        source "$BASHGENCY_ENV"
        set +a
        BASHGENCY_PROVIDER="${BASHGENCY_PROVIDER//$'\r'/}"
        BASHGENCY_PROVIDER="${BASHGENCY_PROVIDER#"${BASHGENCY_PROVIDER%%[![:space:]]*}"}"
        BASHGENCY_PROVIDER="${BASHGENCY_PROVIDER%"${BASHGENCY_PROVIDER##*[![:space:]]}"}"
    else
        echo "${F_RED}${BOLD}[ ERROR ]${RESET} Configuration file not found: ${F_YELLOW}$BASHGENCY_ENV${RESET}"
        echo "  Create the file with:"
        echo "  ${F_GREEN}cp env.example $BASHGENCY_ENV${RESET}"
        echo "  Set ${F_CYAN}BASHGENCY_PROVIDER${RESET} and the matching API key (e.g. DEEPSEEK_API_KEY)."
        return 1
    fi

    if [ -n "$provider_override" ]; then
        provider=$(__bashgency_provider_resolve "$provider_override") || return 1
    else
        provider=$(__bashgency_provider_resolve "${BASHGENCY_PROVIDER:-}") || return 1
    fi
    __bashgency_provider_validate "$provider" || return 1
    __bashgency_provider_set_active "$provider" >/dev/null || return 1
}

__bashgency_aliases_path() {
    local default_path
    if [ -f "$BASHGENCY_ENV" ]; then
        source "$BASHGENCY_ENV"
    fi
    if [ -n "${BASHGENCY_TARGET:-}" ]; then
        printf '%s' "$BASHGENCY_TARGET"
        return 0
    fi
    __bashgency_ensure_dirs
    default_path="$BASHGENCY_DIR/aliases.sh"
    if [ ! -f "$default_path" ]; then
        touch "$default_path"
    fi
    printf '%s' "$default_path"
}

__bashgency_env_path() {
    if [ -n "${BASHGENCY_ENV:-}" ]; then
        printf '%s' "$BASHGENCY_ENV"
    else
        printf '%s' "${HOME}/.config/bashgency/env"
    fi
}

__bashgency_cli_path() {
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    printf '%s' "$lib_dir/../bashgency-cli.sh"
}

__bashgency_var_indirect() {
    local var_name="$1"
    local default="${2:-}"
    local val=""
    if [ -n "${ZSH_VERSION:-}" ]; then
        val="${(P)var_name}"
        printf '%s' "${val:-$default}"
        return 0
    fi
    if [ -n "${BASH_VERSION:-}" ]; then
        printf '%s' "${!var_name:-$default}"
        return 0
    fi
    eval "val=\${${var_name}:-}"
    printf '%s' "${val:-$default}"
}

__bashgency_module_path() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        print -r -- "${${(%):-%x}:A}" 2>/dev/null
    elif [ -n "${BASH_VERSION:-}" ]; then
        realpath "${BASH_SOURCE[0]}" 2>/dev/null
    fi
}

__bashgency_datetime() {
    local fmt="${1:-%Y-%m-%d %H:%M:%S}"
    date +"$fmt"
}

__BASHGENCY_CORE_LOADED=1
