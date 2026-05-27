#!/usr/bin/env bash
#
# bashgency-cli.sh - Bashgency CLI (DeepSeek) - Entry Point
#
# Dependencies:
#   Required: curl, jq
#   Optional: boxes (decorative borders)
#
# Usage: source ~/lab/bashgency/modules/bashgency-cli.sh
#
# Configuration:
#   echo 'DEEPSEEK_API_KEY="sk-your-key"' > ~/.config/bashgency/env
#
# Exported functions:
#   bashgency               - main CLI
#
# Internal modules (sourced from lib/):
#   colors.sh  - Terminal colors & formatting
#   core.sh    - Config paths, env loading
#   io.sh      - File operations (backup, history)
#   parser.sh  - AI output parsing
#   ui.sh      - UI components (boxes, panels, menus)
#   api.sh     - DeepSeek API interaction
#   env.sh     - Shell/OS detection, first-run setup
#   apply.sh   - Apply AI-generated aliases/functions/modules
#

# Guard: prevent double-source
if [ -n "${__BASHGENCY_CLI_LOADED:-}" ]; then
    return 0
fi

# Resolve lib directory relative to this script's location
# Compatible with bash (BASH_SOURCE) and zsh ($0 when sourced)
__BASHGENCY_SRC="${BASH_SOURCE[0]:-$0}"
__BASHGENCY_DIR="$(cd "$(dirname "$__BASHGENCY_SRC")" 2>/dev/null && pwd)"
__BASHGENCY_LIB_DIR="$__BASHGENCY_DIR/lib"

# Source modules in dependency order
if [ -d "$__BASHGENCY_LIB_DIR" ]; then
  source "$__BASHGENCY_LIB_DIR/colors.sh"
  source "$__BASHGENCY_LIB_DIR/core.sh"
  source "$__BASHGENCY_LIB_DIR/parser.sh"
  source "$__BASHGENCY_LIB_DIR/io.sh"
  source "$__BASHGENCY_LIB_DIR/ui.sh"
  source "$__BASHGENCY_LIB_DIR/api.sh"
  source "$__BASHGENCY_LIB_DIR/env.sh"
  source "$__BASHGENCY_LIB_DIR/apply.sh"
fi

# ============================================================
# MAIN CLI
# ============================================================
bashgency() {
    emulate -L sh 2>/dev/null
    set +x 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null

    local prompt=""
    local preview=false
    local force=false
    local model="deepseek-chat"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt) prompt="$2"; shift 2 ;;
            -v|--preview) preview=true; shift ;;
            -f|--force) force=true; shift ;;
            -m|--model) model="$2"; shift 2 ;;
            -h|--help)
                __bashgency_box " BASHGENCY - HELP "
                echo ""
                echo " ${F_GREEN}USAGE:${RESET}"
                echo "   bashgency                          ${F_CYAN}# Interactive mode${RESET}"
                echo "   bashgency -p \"description\"         ${F_CYAN}# Direct mode${RESET}"
                echo "   bashgency -p \"desc\" --preview      ${F_CYAN}# Preview only${RESET}"
                echo "   bashgency -p \"desc\" --force        ${F_CYAN}# Skip confirmation${RESET}"
                echo ""
                echo " ${F_YELLOW}FLAGS:${RESET}"
                echo "   -p, --prompt   Describe the alias/function you need"
                echo "   -v, --preview  Show generated code without applying"
                echo "   -f, --force    Apply without confirmation"
                echo "   -m, --model    DeepSeek model (default: deepseek-chat)"
                echo "   -h, --help     Show this help"
                echo ""
                echo " ${F_MAGENTA}EXAMPLES:${RESET}"
                echo "   bashgency"
                echo '   bashgency -p "alias to show a colorful diff with stat"'
                echo '   bashgency -p "function to create a branch with date in the name" --preview'
                echo ""
                return 0
                ;;
            *) prompt="$1"; shift ;;
        esac
    done

    # First run check - detect environment and setup if needed
    __bashgency_first_run_check || return $?

    while true; do
        # --- INTERACTIVE MODE ---
        if [ -z "$prompt" ]; then
            clear
            __bashgency_box " BASHGENCY - AUTOMATION ASSISTANT "
            echo ""
            echo " ${F_GREEN}Describe what you need to automate:${RESET}"
            echo " ${F_CYAN}>${RESET} 'alias to open VS Code on the current branch'"
            echo " ${F_CYAN}>${RESET} 'function to deploy to production with confirmation'"
            echo " ${F_CYAN}>${RESET} 'alias to clean local branches that no longer exist on remote'"
            echo ""
            echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
            read -r prompt
            echo ""
            if [ -z "$prompt" ]; then
                echo " ${F_RED}${BOLD}[!]${RESET} No description provided. Cancelling."
                return 1
            fi
        fi

        # --- API CALL ---
        echo ""
        printf " ${F_DIM}generating suggestion via %s...${RESET}" "$model"

        local t0 t1 elapsed
        t0=$(date +%s)

        local response http_code body ai_content
        response=$(__bashgency_call_api "$prompt" "$model")
        t1=$(date +%s)
        elapsed=$((t1 - t0))

        printf "\r\033[K"

        # Parse HTTP response
        http_code=$(printf '%s' "$response" | tail -n1 | tr -d '[:space:]')
        if [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
            body=$(printf '%s' "$response" | sed '$d')
        else
            http_code="${response: -3}"
            body="${response:0:${#response}-3}"
        fi

        if [ "$http_code" != "200" ]; then
            echo ""
            echo " ${F_RED}${BOLD}[ HTTP ERROR ${http_code} ]${RESET}"
            echo "${F_YELLOW}Raw response (first 1500 chars):${RESET}"
            echo "$body" | head -c 1500
            echo ""
            echo "$body" | jq -r '.error.message // "Unknown error (no .error.message in JSON)"' 2>/dev/null || echo "$body"
            echo ""
            return 1
        fi

        ai_content=$(__bashgency_extract_content "$body") || ai_content=""

        if [ -z "$ai_content" ]; then
            echo ""
            echo " ${F_RED}${BOLD}[!]${RESET} Empty API response."
            echo " ${F_YELLOW}HTTP Code: $http_code${RESET}"
            echo " ${F_YELLOW}Body (raw, first 2000 chars):${RESET}"
            echo "$body" | head -c 2000
            echo ""
            return 1
        fi

        # --- SHOW GENERATED CODE PREVIEW ---
        __bashgency_show_consult "$prompt" "$model" "$elapsed"
        __bashgency_render_preview "$ai_content"
        echo ""

        # Preview only: stop here
        if [ "$preview" = true ]; then
            echo " ${F_YELLOW}${BOLD}[ PREVIEW ]${RESET} Nothing was applied."
            return 0
        fi

        if [ "$force" = true ]; then
            __bashgency_apply_changes "$prompt" "$ai_content"
            return 0
        fi

        # --- ACTION MENU ---
        local action=""
        while [ -z "$action" ]; do
            __bashgency_show_action_menu
            read -r choice
            case "$choice" in
                1|a|A|apply|APPLY|aplicar|APLICAR) action=apply ;;
                2|n|N|no|NO|nao|NAO|nao\ aplicar|NAO\ APLICAR) action=retry ;;
                3|s|S|exit|EXIT|quit|QUIT|sair|SAIR|q|Q) action=exit ;;
                *)
                    echo " ${F_RED}Invalid option.${RESET} Choose 1, 2, or 3."
                    ;;
            esac
        done

        case "$action" in
            apply)
                __bashgency_apply_changes "$prompt" "$ai_content"
                return 0
                ;;
            retry)
                prompt=""
                action=""
                echo ""
                continue
                ;;
            exit)
                __bashgency_farewell
                return 0
                ;;
        esac
    done
}

__BASHGENCY_CLI_LOADED=1
