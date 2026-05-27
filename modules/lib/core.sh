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
    __bashgency_ensure_dirs
    if [ -f "$BASHGENCY_ENV" ]; then
        source "$BASHGENCY_ENV"
    else
        echo "${F_RED}${BOLD}[ ERROR ]${RESET} Configuration file not found: ${F_YELLOW}$BASHGENCY_ENV${RESET}"
        echo "  Create the file with:"
        echo "  ${F_GREEN}echo 'DEEPSEEK_API_KEY=\"sk-your-key\"' > $BASHGENCY_ENV${RESET}"
        return 1
    fi
    if [ -z "$DEEPSEEK_API_KEY" ]; then
        echo "${F_RED}${BOLD}[ ERROR ]${RESET} DEEPSEEK_API_KEY not set in ${F_YELLOW}$BASHGENCY_ENV${RESET}"
        return 1
    fi
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
