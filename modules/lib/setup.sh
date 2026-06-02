#!/usr/bin/env bash
# setup.sh - Env file read/write and provider configuration wizard
# Part of Bashgency (no HTTP/provider deps)

if [ -n "${__BASHGENCY_SETUP_LOADED:-}" ]; then
    return 0
fi

__bashgency_setup_env_file() {
    if [ -n "${BASHGENCY_ENV:-}" ]; then
        printf '%s' "$BASHGENCY_ENV"
        return 0
    fi
    local dir="${BASHGENCY_DIR:-$HOME/.config/bashgency}"
    printf '%s' "$dir/env"
}

__bashgency_provider_key_var() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r')" in
        deepseek)  printf '%s' DEEPSEEK_API_KEY ;;
        openai)    printf '%s' OPENAI_API_KEY ;;
        anthropic) printf '%s' ANTHROPIC_API_KEY ;;
        gemini)    printf '%s' GEMINI_API_KEY ;;
        *)         return 1 ;;
    esac
}

__bashgency_provider_key_hint() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r')" in
        deepseek|openai) printf '%s' 'sk-...' ;;
        anthropic)       printf '%s' 'sk-ant-...' ;;
        gemini)          printf '%s' 'AIza...' ;;
        *)               printf '%s' 'api-key' ;;
    esac
}

__bashgency_provider_key_placeholder() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r')" in
        deepseek|openai) printf '%s' 'sk-your-key-here' ;;
        anthropic)       printf '%s' 'sk-ant-your-key-here' ;;
        gemini)          printf '%s' 'AIza-your-key-here' ;;
        *)               printf '%s' 'sk-your-key-here' ;;
    esac
}

__bashgency_env_get_var() {
    local var="$1"
    local env_file="${2:-$(__bashgency_setup_env_file)}"
    local raw val

    [ -f "$env_file" ] || return 1
    raw=$(grep -E "^${var}=" "$env_file" 2>/dev/null | head -1) || return 1
    val="${raw#*=}"
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
    val=$(printf '%s' "$val" | tr -d '\r')
    printf '%s' "$val"
}

__bashgency_env_set_var() {
    local var="$1"
    local val="$2"
    local env_file="${3:-$(__bashgency_setup_env_file)}"
    local tmp escaped_line found=0

    [ -f "$env_file" ] || touch "$env_file"
    chmod 600 "$env_file" 2>/dev/null || true

    escaped_line=$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')
    tmp=$(mktemp)
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^${var}= ]]; then
            printf '%s="%s"\n' "$var" "$escaped_line"
            found=1
        else
            printf '%s\n' "$line"
        fi
    done < "$env_file" > "$tmp"
    if [ "$found" -eq 0 ]; then
        printf '%s="%s"\n' "$var" "$escaped_line" >> "$tmp"
    fi
    mv "$tmp" "$env_file"
    chmod 600 "$env_file" 2>/dev/null || true
}

__bashgency_env_get_provider() {
    local env_file="${1:-$(__bashgency_setup_env_file)}"
    local provider
    provider=$(__bashgency_env_get_var BASHGENCY_PROVIDER "$env_file" 2>/dev/null) || provider=""
    provider="${provider:-deepseek}"
    printf '%s' "$provider" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r'
}

__bashgency_env_provider_configured() {
    local env_file="${1:-$(__bashgency_setup_env_file)}"
    local provider key_var key_val placeholder

    [ -f "$env_file" ] || return 1
    provider=$(__bashgency_env_get_provider "$env_file")
    key_var=$(__bashgency_provider_key_var "$provider") || return 1
    key_val=$(__bashgency_env_get_var "$key_var" "$env_file" 2>/dev/null) || key_val=""
    placeholder=$(__bashgency_provider_key_placeholder "$provider")

    [ -n "$key_val" ] && [ "$key_val" != "$placeholder" ]
}

__bashgency_provider_key_ok() {
    local id="$1"
    local env_file="${2:-$(__bashgency_setup_env_file)}"
    __bashgency_env_provider_configured "$env_file" && \
        [ "$(__bashgency_env_get_provider "$env_file")" = "$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r')" ]
}

__bashgency_provider_key_ok_for() {
    local id="$1"
    local env_file="${2:-$(__bashgency_setup_env_file)}"
    local key_var key_val placeholder

    id=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]\r')
    key_var=$(__bashgency_provider_key_var "$id") || return 1
    key_val=$(__bashgency_env_get_var "$key_var" "$env_file" 2>/dev/null) || key_val=""
    placeholder=$(__bashgency_provider_key_placeholder "$id")
    [ -n "$key_val" ] && [ "$key_val" != "$placeholder" ]
}

__bashgency_configure_provider_interactive() {
    local env_file="${1:-$(__bashgency_setup_env_file)}"
    local tty_in="${2:-/dev/tty}"
    local selected_provider="" key_var key_hint user_key

    if [ ! -t 0 ] && [ ! -r "$tty_in" ]; then
        echo "${F_RED:-}${BOLD:-}[ ERROR ]${RESET:-} Interactive configuration requires a TTY." >&2
        echo "  Edit ${F_YELLOW:-}${env_file}${RESET:-} or run: bashgency --configure" >&2
        return 1
    fi

    printf "\n"
    printf "  ${F_CYAN:-}?${RESET:-} Select AI provider:\n\n"
    printf "    ${F_CYAN:-}${BOLD:-}1${RESET:-}  DeepSeek\n"
    printf "    ${F_CYAN:-}${BOLD:-}2${RESET:-}  OpenAI\n"
    printf "    ${F_CYAN:-}${BOLD:-}3${RESET:-}  Anthropic\n"
    printf "    ${F_CYAN:-}${BOLD:-}4${RESET:-}  Google Gemini\n"
    printf "    ${F_CYAN:-}${BOLD:-}5${RESET:-}  Cancel\n\n"
    printf "  ${F_CYAN:-}?${RESET:-} Choice [1-5]: "
    read -r provider_choice <"$tty_in" 2>/dev/null || read -r provider_choice

    case "$provider_choice" in
        1) selected_provider=deepseek ;;
        2) selected_provider=openai ;;
        3) selected_provider=anthropic ;;
        4) selected_provider=gemini ;;
        5|"") return 1 ;;
        *) selected_provider=deepseek ;;
    esac

    __bashgency_env_set_var BASHGENCY_PROVIDER "$selected_provider" "$env_file"
    printf "  ${F_GREEN:-}[ + ]${RESET:-} BASHGENCY_PROVIDER set to ${F_CYAN:-}${selected_provider}${RESET:-}\n"

    key_var=$(__bashgency_provider_key_var "$selected_provider")
    key_hint=$(__bashgency_provider_key_hint "$selected_provider")
    printf "\n  ${F_CYAN:-}?${RESET:-} Enter your %s API key (${F_DIM:-}%s${RESET:-}): " "$selected_provider" "$key_hint"
    read -r user_key <"$tty_in" 2>/dev/null || read -r user_key
    user_key="${user_key//$'\r'/}"
    user_key="${user_key#"${user_key%%[![:space:]]*}"}"
    user_key="${user_key%"${user_key##*[![:space:]]}"}"

    if [ -z "$user_key" ]; then
        echo "  ${F_YELLOW:-}[!]${RESET:-} No key entered."
        return 1
    fi

    __bashgency_env_set_var "$key_var" "$user_key" "$env_file"
    echo "  ${F_GREEN:-}[ + ]${RESET:-} ${key_var} saved to ${F_BLUE:-}${env_file}${RESET:-}"
    return 0
}

__BASHGENCY_SETUP_LOADED=1
