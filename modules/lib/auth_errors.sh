#!/usr/bin/env bash
# auth_errors.sh - HTTP error classification and API key recovery
# Part of Bashgency

if [ -n "${__BASHGENCY_AUTH_ERRORS_LOADED:-}" ]; then
    return 0
fi

__bashgency_http_is_auth_error() {
    case "$1" in
        401|403) return 0 ;;
        *) return 1 ;;
    esac
}

__bashgency_http_error_summary() {
    local http_code="$1"
    local body="$2"
    local family="${3:-openai_compat}"
    local msg=""

    body=$(__bashgency_sanitize_json_body "$body" 2>/dev/null || printf '%s' "$body")

    case "$family" in
        anthropic)
            msg=$(printf '%s' "$body" | jq -r '.error.message // .error.type // empty' 2>/dev/null)
            ;;
        gemini)
            msg=$(printf '%s' "$body" | jq -r '.error.message // .error.status // empty' 2>/dev/null)
            ;;
        openai_compat|*)
            msg=$(printf '%s' "$body" | jq -r '.error.message // .error.code // empty' 2>/dev/null)
            ;;
    esac

    if [ -z "$msg" ]; then
        msg=$(printf '%s' "$body" | head -c 200)
    fi
    printf '%s' "$msg"
}

__bashgency_auth_can_reconfigure() {
    [ -z "${BASHGENCY_NONINTERACTIVE:-}" ] && [ -t 0 ]
}

__bashgency_handle_http_error() {
    local http_code="$1"
    local body="$2"
    local provider="${3:-${BASHGENCY_ACTIVE_PROVIDER:-}}"
    local family msg env_path

    env_path="$(__bashgency_env_path)"
    family=$(__bashgency_provider_family "$provider" 2>/dev/null) || family="openai_compat"
    msg=$(__bashgency_http_error_summary "$http_code" "$body" "$family")

    echo ""
    if __bashgency_http_is_auth_error "$http_code"; then
        echo " ${F_RED}${BOLD}[ AUTH ERROR ${http_code} ]${RESET} Authentication failed for ${F_CYAN}${provider}${RESET}."
        [ -n "$msg" ] && echo " ${F_YELLOW}Details:${RESET} $msg"
        echo ""
        echo " ${F_DIM}Config file:${RESET} ${F_BLUE}${env_path}${RESET}"
        if __bashgency_auth_can_reconfigure; then
            echo ""
            echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} Reconfigure API key now? ${F_GREEN}[Y/n]${RESET} "
            local answer
            read -r answer
            case "$answer" in
                n|N|no|NO|nao|NAO)
                    echo " ${F_YELLOW}Edit ${env_path} or run: bashgency --configure${RESET}"
                    return 2
                    ;;
            esac
            if __bashgency_configure_provider_interactive "$env_path"; then
                __bashgency_load_env "$provider" || return 2
                if ! __bashgency_verify_provider_api "$provider"; then
                    echo ""
                    echo " ${F_YELLOW}[!]${RESET} Key saved, but the API still rejected the request."
                    echo " ${F_DIM}Check the key on the provider dashboard, balance, and that you use the correct product (DeepSeek API vs OpenAI).${RESET}"
                    return 2
                fi
                echo " ${F_GREEN}[ + ]${RESET} API key verified."
                return 0
            fi
            return 2
        fi
        echo " ${F_YELLOW}Run:${RESET} ${F_GREEN}bashgency --configure${RESET}"
        return 2
    fi

    echo " ${F_RED}${BOLD}[ HTTP ERROR ${http_code} ]${RESET}"
    [ -n "$msg" ] && echo " ${F_YELLOW}Details:${RESET} $msg"
    echo "${F_DIM}Response (first 1500 chars):${RESET}"
    printf '%s' "$body" | head -c 1500
    echo ""
    return 1
}

__BASHGENCY_AUTH_ERRORS_LOADED=1
