#!/usr/bin/env bash
# env.sh - Shell/OS detection, first-run setup
# Part of Bashgency

if [ -n "${__BASHGENCY_ENV_LOADED:-}" ]; then
    return 0
fi

__BASHGENCY_INIT_MARKER="$BASHGENCY_DIR/.initialized"

__bashgency_detect_shell() {
    local shell_type=""
    local rc_file=""

    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_type="zsh"
        rc_file="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
        shell_type="bash"
        rc_file="$HOME/.bashrc"
    else
        case "${SHELL##*/}" in
            zsh)
                shell_type="zsh"
                rc_file="$HOME/.zshrc"
                ;;
            bash)
                shell_type="bash"
                rc_file="$HOME/.bashrc"
                ;;
            *)
                shell_type="${SHELL##*/}"
                [ -f "$HOME/.zshrc" ] && rc_file="$HOME/.zshrc"
                [ -f "$HOME/.bashrc" ] && rc_file="$HOME/.bashrc"
                [ -f "$HOME/.config/fish/config.fish" ] && rc_file="$HOME/.config/fish/config.fish"
                ;;
        esac
    fi

    printf '%s:%s' "$shell_type" "$rc_file"
}

__bashgency_detect_os() {
    case "$(uname -s)" in
        Darwin) printf 'macos' ;;
        Linux)  printf 'linux' ;;
        *)      printf '%s' "$(uname -s)" ;;
    esac
}

__bashgency_escape_grep() {
    printf '%s' "$1" | sed 's/[[\.*?^$()+{|]/\\&/g'
}

__bashgency_first_run_check() {
    if [ -f "$__BASHGENCY_INIT_MARKER" ] && __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
        return 0
    fi

    local detected
    detected=$(__bashgency_detect_shell)
    local shell_type="${detected%%:*}"
    local rc_file="${detected#*:}"
    local os_type
    os_type=$(__bashgency_detect_os)

    __bashgency_ensure_dirs

    local needs_setup=false
    local missing_items=""
    local alias_path
    alias_path=$(__bashgency_aliases_path)

    if [ ! -f "$BASHGENCY_ENV" ]; then
        missing_items="${missing_items}  ${F_YELLOW}*${RESET} Config file (${F_BLUE}$BASHGENCY_ENV${RESET})\n"
        needs_setup=true
    elif ! __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
        missing_items="${missing_items}  ${F_YELLOW}*${RESET} BASHGENCY_PROVIDER + matching API key in ${F_BLUE}$BASHGENCY_ENV${RESET}\n"
        needs_setup=true
    fi

    if [ ! -f "$alias_path" ]; then
        missing_items="${missing_items}  ${F_YELLOW}*${RESET} Aliases file (${F_BLUE}$alias_path${RESET})\n"
        needs_setup=true
    fi

    local needs_rc=false
    if [ -z "$rc_file" ]; then
        missing_items="${missing_items}  ${F_YELLOW}*${RESET} Shell rc file not detected\n"
        needs_setup=true
    elif [ ! -f "$rc_file" ]; then
        needs_rc=true
        missing_items="${missing_items}  ${F_YELLOW}*${RESET} Sourcing lines in ${F_BLUE}$rc_file${RESET} (file will be created)\n"
        needs_setup=true
    else
        local escaped_alias_path
        escaped_alias_path=$(__bashgency_escape_grep "$alias_path")
        if ! grep -qF "$alias_path" "$rc_file" 2>/dev/null; then
            needs_rc=true
            missing_items="${missing_items}  ${F_YELLOW}*${RESET} Aliases sourcing in ${F_BLUE}$rc_file${RESET}\n"
            needs_setup=true
        fi
    fi

    if [ "$needs_setup" = false ]; then
        touch "$__BASHGENCY_INIT_MARKER"
        return 0
    fi

    clear
    __bashgency_box " FIRST RUN - SETUP REQUIRED "
    echo ""
    echo " ${F_GREEN}Shell${RESET}    ${shell_type:-${F_YELLOW}(not detected)${RESET}}"
    echo " ${F_GREEN}OS${RESET}       ${os_type}"
    echo " ${F_GREEN}Rc file${RESET}  ${rc_file:-${F_YELLOW}(not detected)${RESET}}"
    echo ""
    echo " ${F_YELLOW}Bashgency needs the following:${RESET}"
    echo ""
    printf "%b" "$missing_items"
    echo ""
    echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} Proceed with automatic setup? ${F_GREEN}[Y/n]${RESET} "
    read -r response
    case "$response" in
        n|N|no|NO|nao|NAO)
            echo ""
            echo " ${F_YELLOW}${BOLD}[!]${RESET} Setup skipped. Run: ${F_GREEN}bashgency --configure${RESET} or ${F_GREEN}bash ~/lab/bashgency/install.sh${RESET}"
            echo ""
            return 1
            ;;
    esac

    __bashgency_box " SETTING UP BASHGENCY "

    if [ ! -f "$BASHGENCY_ENV" ]; then
        local repo_root
        repo_root="$(dirname "$(dirname "$(__bashgency_module_path)")")"
        if [ -f "$repo_root/env.example" ]; then
            cp "$repo_root/env.example" "$BASHGENCY_ENV"
        else
            cat > "$BASHGENCY_ENV" <<'EOF'
# Bashgency config
BASHGENCY_PROVIDER="deepseek"
DEEPSEEK_API_KEY="sk-your-key-here"
OPENAI_API_KEY="sk-your-key-here"
ANTHROPIC_API_KEY="sk-ant-your-key-here"
GEMINI_API_KEY="AIza-your-key-here"
EOF
        fi
        chmod 600 "$BASHGENCY_ENV"
        echo " ${F_GREEN}${BOLD}[ + ]${RESET} Created ${F_BLUE}$BASHGENCY_ENV${RESET}"
    fi

    if ! __bashgency_env_provider_configured "$BASHGENCY_ENV" ] && [ -t 0 ]; then
        __bashgency_configure_provider_interactive "$BASHGENCY_ENV" || true
    elif ! __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
        echo " ${F_YELLOW}${BOLD}[!]${RESET} Set ${F_CYAN}BASHGENCY_PROVIDER${RESET} and matching API key in ${F_BLUE}$BASHGENCY_ENV${RESET}"
    fi

    if [ ! -f "$alias_path" ]; then
        touch "$alias_path"
        echo " ${F_GREEN}${BOLD}[ + ]${RESET} Created ${F_BLUE}$alias_path${RESET}"
    fi

    if [ -n "$rc_file" ] && [ "$needs_rc" = true ]; then
        if [ ! -f "$rc_file" ]; then
            touch "$rc_file"
            echo " ${F_GREEN}${BOLD}[ + ]${RESET} Created ${F_BLUE}$rc_file${RESET}"
        fi
        {
            echo ""
            echo "# >>> Bashgency - AI-powered alias generator"
        } >> "$rc_file"

        local bashgency_script_path
        bashgency_script_path="$(__bashgency_cli_path)"
        if ! grep -qF "$bashgency_script_path" "$rc_file" 2>/dev/null; then
            echo "[ -f \"$bashgency_script_path\" ] && source \"$bashgency_script_path\"" >> "$rc_file"
            echo " ${F_GREEN}${BOLD}[ + ]${RESET} Added bashgency source line to ${F_BLUE}$rc_file${RESET}"
        fi

        if ! grep -qF "$alias_path" "$rc_file" 2>/dev/null; then
            echo "[ -f \"$alias_path\" ] && source \"$alias_path\"" >> "$rc_file"
            echo " ${F_GREEN}${BOLD}[ + ]${RESET} Added aliases source line to ${F_BLUE}$rc_file${RESET}"
        fi

        {
            echo "# <<< Bashgency"
        } >> "$rc_file"
    fi

    if __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
        touch "$__BASHGENCY_INIT_MARKER"
    fi
    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Initialization complete"

    echo ""
    __bashgency_box " SETUP COMPLETE "
    echo ""
    echo " ${F_GREEN}Bashgency is now configured for ${F_CYAN}${shell_type}${RESET} on ${F_CYAN}${os_type}${RESET}."
    echo ""
    echo " ${F_YELLOW}${BOLD}[~]${RESET} Reload your shell or run:"
    echo "    ${F_GREEN}source $rc_file${RESET}"
    echo ""
    if ! __bashgency_env_provider_configured "$BASHGENCY_ENV"; then
        local active_provider active_key_var
        active_provider=$(__bashgency_env_get_provider "$BASHGENCY_ENV")
        active_key_var=$(__bashgency_provider_key_var "$active_provider")
        echo " ${F_YELLOW}${BOLD}[!]${RESET} Add your API key: ${F_GREEN}bashgency --configure${RESET}"
        echo "    ${F_CYAN}BASHGENCY_PROVIDER=\"${active_provider}\"${RESET}"
        echo "    ${F_CYAN}${active_key_var}=\"...\"${RESET}"
        echo ""
    fi

    [ -f "$alias_path" ] && source "$alias_path" 2>/dev/null
    return 0
}

__BASHGENCY_ENV_LOADED=1
