#!/usr/bin/env bash
#
# bashgency-cli.sh - Bashgency CLI (multi-provider) - Entry Point
#
# Dependencies:
#   Required: curl, jq
#   Optional: boxes (decorative borders)
#
# Usage: source ~/lab/bashgency/modules/bashgency-cli.sh
#
# Configuration:
#   cp env.example ~/.config/bashgency/env
#   Set BASHGENCY_PROVIDER and matching API key (see env.example)
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
#   api.sh     - AI provider API interaction
#   env.sh     - Shell/OS detection, first-run setup
#   apply.sh      - Apply AI-generated aliases/functions/modules
#   inventory.sh  - Interactive inventory browser
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
  source "$__BASHGENCY_LIB_DIR/setup.sh"
  source "$__BASHGENCY_LIB_DIR/providers/registry.sh"
  source "$__BASHGENCY_LIB_DIR/parser.sh"
  source "$__BASHGENCY_LIB_DIR/io.sh"
  source "$__BASHGENCY_LIB_DIR/ui.sh"
  source "$__BASHGENCY_LIB_DIR/api.sh"
  source "$__BASHGENCY_LIB_DIR/auth_errors.sh"
  source "$__BASHGENCY_LIB_DIR/env.sh"
  source "$__BASHGENCY_LIB_DIR/apply.sh"
  source "$__BASHGENCY_LIB_DIR/inventory.sh"
  source "$__BASHGENCY_LIB_DIR/run.sh"
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
    local provider=""
    local model=""
    local inventory_mode=false
    local run_mode=false
    local configure_mode=false
    local main_choice=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --configure|configure|config)
                configure_mode=true
                shift
                ;;
            -p|--prompt) prompt="$2"; shift 2 ;;
            -v|--preview) preview=true; shift ;;
            -f|--force) force=true; shift ;;
            -y|--yes) force=true; shift ;;
            -P|--provider) provider="$2"; shift 2 ;;
            -m|--model) model="$2"; shift 2 ;;
            -r|--run) run_mode=true; shift ;;
            --run) run_mode=true; shift ;;  # zsh compat
            -i|--inventory|inventory) inventory_mode=true; shift ;;
            -h|--help)
                __bashgency_box " BASHGENCY - HELP "
                echo ""
                echo " ${F_GREEN}USAGE:${RESET}"
                echo "   bashgency                          ${F_CYAN}# Interactive mode${RESET}"
                echo "   bashgency -p \"description\"         ${F_CYAN}# Create alias/function/module${RESET}"
                echo "   bashgency -p \"desc\" --preview      ${F_CYAN}# Preview only${RESET}"
                echo "   bashgency -p \"desc\" --force        ${F_CYAN}# Skip confirmation${RESET}"
                echo "   bashgency -i                       ${F_CYAN}# Inventory browser${RESET}"
                echo "   bashgency --inventory              ${F_CYAN}# Inventory browser${RESET}"
                echo "   bashgency -r \"description\"         ${F_CYAN}# Run command from description${RESET}"
                echo "   bashgency -r \"desc\" -y             ${F_CYAN}# Run without confirmation${RESET}"
                echo ""
                echo " ${F_YELLOW}FLAGS:${RESET}"
                echo "   -p, --prompt    Describe the alias/function you need"
                echo "   -v, --preview   Show generated code without applying"
                echo "   -f, --force     Apply without confirmation"
                echo "   -y, --yes       Auto-confirm execution ${F_DIM}(run mode)${RESET}"
                echo "   -r, --run       Run a command from natural language"
                echo "   -i, --inventory Browse all created aliases/functions/modules"
                echo "   -P, --provider  AI provider override (see table below)"
                echo "   -m, --model     Model override (default: per active provider)"
                echo "   --configure     Interactive provider + API key setup"
                echo "   -h, --help      Show this help"
                echo ""
                echo " ${F_YELLOW}ENV:${RESET}"
                echo "   BASHGENCY_NONINTERACTIVE=1  Suppress reconfigure prompts on auth errors"
                echo ""
                echo " ${F_YELLOW}PROVIDERS:${RESET}"
                __bashgency_provider_list_display
                echo ""
                echo " ${F_MAGENTA}EXAMPLES:${RESET}"
                echo "   bashgency"
                echo '   bashgency -p "alias to show a colorful diff with stat"'
                echo '   bashgency -p "function to create a branch with date in the name" --preview'
                echo '   bashgency -r "list all text files containing lorem ipsum"'
                echo '   bashgency -r "find the 5 largest files" -y'
                echo "   bashgency -i"
                echo ""
                return 0
                ;;
            *) prompt="$1"; shift ;;
        esac
    done

    if [ "$configure_mode" = true ]; then
        __bashgency_ensure_dirs
        if [ ! -f "$BASHGENCY_ENV" ]; then
            local repo_root
            repo_root="$(dirname "$__BASHGENCY_DIR")"
            if [ -f "$repo_root/env.example" ]; then
                cp "$repo_root/env.example" "$BASHGENCY_ENV"
            else
                touch "$BASHGENCY_ENV"
            fi
            chmod 600 "$BASHGENCY_ENV"
        fi
        __bashgency_configure_provider_interactive "$BASHGENCY_ENV" || return 1
        __bashgency_load_env || return 1
        if ! __bashgency_verify_provider_api; then
            echo " ${F_YELLOW}[!]${RESET} Configuration saved, but the API test failed. Fix the key and run ${F_GREEN}bashgency --configure${RESET} again."
            return 1
        fi
        echo " ${F_GREEN}[ + ]${RESET} API key verified."
        if __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
            touch "$BASHGENCY_DIR/.initialized" 2>/dev/null || true
        fi
        return 0
    fi

    # Inventory mode: shortcut to browser
    if [ "$inventory_mode" = true ]; then
        __bashgency_first_run_check || return $?
        __bashgency_inventory
        return $?
    fi

    # Run mode: semantic command execution
    if [ "$run_mode" = true ]; then
        __bashgency_first_run_check || return $?
        __bashgency_run_flow "$prompt" "$model" "$force" "$provider"
        return $?
    fi

    # First run check - detect environment and setup if needed
    __bashgency_first_run_check || return $?

    while true; do
        # --- INTERACTIVE MODE ---
        if [ -z "$prompt" ]; then
            clear
            __bashgency_box " BASHGENCY - AUTOMATION ASSISTANT "
            echo ""
            echo " ${F_GREEN}What do you want to do?${RESET}"
            echo ""
            echo " ${F_CYAN}${BOLD}1${RESET}  Create a new alias, function, or module"
            echo " ${F_CYAN}${BOLD}2${RESET}  Browse inventory ${F_DIM}(view all created items)${RESET}"
            echo " ${F_CYAN}${BOLD}3${RESET}  Configure provider / API key"
            echo " ${F_CYAN}${BOLD}4${RESET}  Help"
            echo " ${F_CYAN}${BOLD}5${RESET}  Exit"
            echo ""
            echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
            read -r main_choice
            echo ""
            case "$main_choice" in
                2|b|B|inventory|"browse"|"list"|"ls")
                    __bashgency_first_run_check || return $?
                    __bashgency_inventory
                    prompt=""
                    continue
                    ;;
                3|c|C|configure|config)
                    bashgency --configure || true
                    prompt=""
                    continue
                    ;;
                4|h|H|"help"|"-h"|"--help")
                    bashgency -h | head -60
                    echo ""
                    echo -ne " ${F_YELLOW}${BOLD}[Enter]${RESET} to return "
                    read -r
                    prompt=""
                    continue
                    ;;
                5|q|Q|exit|quit|sair)
                    __bashgency_farewell
                    return 0
                    ;;
                1|a|A|create|"new"|"criar")
                    :  # fall through to prompt
                    ;;
                *)
                    :  # treat as prompt input
                    prompt="$main_choice"
                    ;;
            esac

            # If choice was 1 or similar, prompt for description
            if [ "$main_choice" = "1" ] || [ "$main_choice" = "a" ] || [ "$main_choice" = "A" ] || [ "$main_choice" = "create" ]; then
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
        fi

        # --- API CALL ---
        __bashgency_load_env "$provider" || return 1
        if [ -z "$model" ]; then
            model=$(__bashgency_provider_default_model "$BASHGENCY_ACTIVE_PROVIDER")
        fi

        echo ""
        printf " ${F_DIM}generating suggestion via %s/%s...${RESET}" "$BASHGENCY_ACTIVE_PROVIDER" "$model"

        local t0 t1 elapsed
        t0=$(date +%s)

        local response parsed http_code body ai_content hr
        response=$(__bashgency_call_api "$prompt" "$model" "$provider")
        t1=$(date +%s)
        elapsed=$((t1 - t0))

        printf "\r\033[K"

        parsed=$(__bashgency_parse_http_response "$response")
        http_code=$(printf '%s' "$parsed" | head -n1)
        body=$(printf '%s' "$parsed" | tail -n +2)

        if [ "$http_code" != "200" ]; then
            __bashgency_handle_http_error "$http_code" "$body" "$BASHGENCY_ACTIVE_PROVIDER"
            hr=$?
            if [ "$hr" -eq 0 ]; then
                response=$(__bashgency_call_api "$prompt" "$model" "$provider")
                parsed=$(__bashgency_parse_http_response "$response")
                http_code=$(printf '%s' "$parsed" | head -n1)
                body=$(printf '%s' "$parsed" | tail -n +2)
            fi
            if [ "$http_code" != "200" ]; then
                if [ "$hr" -eq 0 ]; then
                    __bashgency_handle_http_error "$http_code" "$body" "$BASHGENCY_ACTIVE_PROVIDER" || return 1
                fi
                return 1
            fi
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
