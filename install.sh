#!/usr/bin/env bash

# Bashgency Installer

# Resolve script directory — compatível bash/zsh
if [ -n "${BASH_SOURCE+x}" ]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
else
    ROOT="$(cd "$(dirname "$0")" && pwd 2>/dev/null)"
fi
CONFIG_DIR="${BASHGENCY_DIR:-$HOME/.config/bashgency}"
MODULE_PATH="$ROOT/modules/bashgency-cli.sh"

# Detect if being sourced (source install.sh) vs executed (./install.sh)
# In bash: BASH_SOURCE[0] != $0 means sourced
# In zsh: sourced -> $0 is file path; executed -> $0 is shell name
IS_SOURCED=false
if [ -n "${BASH_SOURCE+x}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ] && IS_SOURCED=true || true
else
    case "$0" in -zsh|zsh|bash|-bash|sh|-sh) ;; *) IS_SOURCED=true ;; esac
fi

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  # Suppress errors if bashgency already set these as readonly
  { RED=$(tput setaf 1 2>/dev/null || echo ''); } 2>/dev/null || true
  { GREEN=$(tput setaf 2 2>/dev/null || echo ''); } 2>/dev/null || true
  { YELLOW=$(tput setaf 3 2>/dev/null || echo ''); } 2>/dev/null || true
  { CYAN=$(tput setaf 6 2>/dev/null || echo ''); } 2>/dev/null || true
  { BOLD=$(tput bold 2>/dev/null || echo ''); } 2>/dev/null || true
  { DIM=$(tput dim 2>/dev/null || echo ''); } 2>/dev/null || true
  { RESET=$(tput sgr0 2>/dev/null || echo ''); } 2>/dev/null || true
  SEP="${DIM}────────────────────────────────────────────────────────${RESET}"
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''; SEP='---'
fi

info()    { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}○${RESET} %s\n" "$*"; }
err()     { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }
heading() { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }
sub()     { printf "  ${DIM}%s${RESET}\n" "$*"; }
divider() { printf "  ${SEP}\n"; }

export BASHGENCY_DIR="$CONFIG_DIR"
export BASHGENCY_ENV="$CONFIG_DIR/env"
# shellcheck source=modules/lib/setup.sh
source "$ROOT/modules/lib/setup.sh"

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n"
printf "  ${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}\n"
printf "  ${BOLD}${CYAN}║${RESET}                 ${BOLD}Bashgency${RESET}                  ${CYAN}║${RESET}\n"
printf "  ${BOLD}${CYAN}║${RESET}         AI-powered shell code generator          ${BOLD}${CYAN}║${RESET}\n"
printf "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}\n"
printf "\n"

# ---------------------------------------------------------------------------
# Step 1/4 — Config directory structure
# ---------------------------------------------------------------------------
heading "> 1/4  ---  Config directory"
divider

mkdir -p "$CONFIG_DIR/modules" "$CONFIG_DIR/backups"
info "Created ${BOLD}$CONFIG_DIR${RESET}"
sub "  |- modules/"
sub "  '- backups/"
divider

# ---------------------------------------------------------------------------
# Step 2/4 — Provider + API key
# ---------------------------------------------------------------------------
heading "> 2/4  ---  Provider + API key"
divider

needs_setup=false
selected_provider=""

if [ ! -f "$CONFIG_DIR/env" ]; then
    cp "$ROOT/env.example" "$CONFIG_DIR/env"
    chmod 600 "$CONFIG_DIR/env"
    info "Created ${BOLD}$CONFIG_DIR/env${RESET}"
    needs_setup=true
else
    warn "${BOLD}$CONFIG_DIR/env${RESET} already exists"
    current_provider=$(__bashgency_env_get_provider "$CONFIG_DIR/env")
    if __bashgency_provider_key_ok_for "$current_provider" "$CONFIG_DIR/env"; then
        key_var=$(__bashgency_provider_key_var "$current_provider")
        info "Provider ${BOLD}${current_provider}${RESET} configured (${key_var} set)"
    else
        needs_setup=true
    fi
fi

if [ "$needs_setup" = true ]; then
    if [ -t 0 ]; then
        printf "\n"
        printf "  ${CYAN}?${RESET} Select AI provider:\n\n"
        printf "    ${BOLD}1${RESET}  DeepSeek\n"
        printf "    ${BOLD}2${RESET}  OpenAI\n"
        printf "    ${BOLD}3${RESET}  Anthropic\n"
        printf "    ${BOLD}4${RESET}  Google Gemini\n"
        printf "    ${BOLD}5${RESET}  Configure later\n\n"
        printf "  ${CYAN}?${RESET} Choice [1-5]: "
        read -r provider_choice </dev/tty 2>/dev/null || read -r provider_choice

        case "$provider_choice" in
            1) selected_provider=deepseek ;;
            2) selected_provider=openai ;;
            3) selected_provider=anthropic ;;
            4) selected_provider=gemini ;;
            5) selected_provider="" ;;
            *) selected_provider=deepseek ;;
        esac

        if [ -n "$selected_provider" ]; then
            __bashgency_env_set_var BASHGENCY_PROVIDER "$selected_provider" "$CONFIG_DIR/env"
            info "BASHGENCY_PROVIDER set to ${BOLD}${selected_provider}${RESET}"

            key_var=$(__bashgency_provider_key_var "$selected_provider")
            key_hint=$(__bashgency_provider_key_hint "$selected_provider")
            printf "\n  ${CYAN}?${RESET} Enter your %s API key (${DIM}%s${RESET}): " "$selected_provider" "$key_hint"
            read -r user_key </dev/tty 2>/dev/null || read -r user_key
            user_key="${user_key//$'\r'/}"
            user_key="${user_key#"${user_key%%[![:space:]]*}"}"
            user_key="${user_key%"${user_key##*[![:space:]]}"}"

            if [ -n "$user_key" ]; then
                __bashgency_env_set_var "$key_var" "$user_key" "$CONFIG_DIR/env"
                info "${key_var} saved to ${BOLD}$CONFIG_DIR/env${RESET}"
            else
                warn "No key entered. Edit ${BOLD}$CONFIG_DIR/env${RESET} later (set ${key_var})"
            fi
        else
            warn "Skipped provider setup. Edit ${BOLD}$CONFIG_DIR/env${RESET} later (BASHGENCY_PROVIDER + matching API key)"
        fi
    else
        warn "Non-interactive install. Edit ${BOLD}$CONFIG_DIR/env${RESET} to set BASHGENCY_PROVIDER and matching API key"
    fi
fi
divider

# ---------------------------------------------------------------------------
# Step 3/4 — Default aliases file
# ---------------------------------------------------------------------------
heading "> 3/4  ---  Aliases destination"
divider

if ! grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
    if [ ! -f "$CONFIG_DIR/aliases.sh" ]; then
        touch "$CONFIG_DIR/aliases.sh"
        info "Created ${BOLD}$CONFIG_DIR/aliases.sh${RESET}  (default target)"
    fi
fi
if [ -f "$CONFIG_DIR/aliases.sh" ]; then
    info "Aliases file: ${BOLD}$CONFIG_DIR/aliases.sh${RESET}"
fi
divider

# ---------------------------------------------------------------------------
# Step 4/4 — Shell integration
# ---------------------------------------------------------------------------
# Lines to add
SOURCE_LINE='[ -f "$HOME/lab/bashgency/modules/bashgency-cli.sh" ] && \'
SOURCE_LINE2='  source "$HOME/lab/bashgency/modules/bashgency-cli.sh"'
ALIASES_LINE='[ -f "$HOME/.config/bashgency/aliases.sh" ] && \'
ALIASES_LINE2='  source "$HOME/.config/bashgency/aliases.sh"'

detect_configs() {
    local candidates=()
    local zdotdir="${ZDOTDIR:-$HOME}"
    [ -f "$zdotdir/.zshrc" ]        && candidates+=("$zdotdir/.zshrc")
    [ -f "$HOME/.bashrc" ]          && candidates+=("$HOME/.bashrc")
    [ -f "$HOME/.bash_profile" ]    && candidates+=("$HOME/.bash_profile")
    [ -f "$HOME/.profile" ]         && candidates+=("$HOME/.profile")
    if [ ${#candidates[@]} -eq 0 ]; then
        case "${SHELL##*/}" in
            zsh)  candidates+=("$zdotdir/.zshrc") ;;
            bash) candidates+=("$HOME/.bashrc") ;;
            *)    candidates+=("$HOME/.zshrc") ;;
        esac
    fi
    printf '%s\n' "${candidates[@]}"
}

already_sourced() {
    local file="$1"
    [ -f "$file" ] && grep -qF 'bashgency-cli.sh' "$file" 2>/dev/null && return 0
    return 1
}

add_source_block() {
    local file="$1"
    {
        echo ""
        echo "# Bashgency"
        echo "$SOURCE_LINE"
        echo "$SOURCE_LINE2"
    } >> "$file"
    if ! grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
        {
            echo "$ALIASES_LINE"
            echo "$ALIASES_LINE2"
        } >> "$file"
    fi
    echo "" >> "$file"
    info "Added Bashgency source lines to ${BOLD}$file${RESET}"
}

heading "> 4/4  ---  Shell integration"
divider

configs=()
while IFS= read -r line; do configs+=("$line"); done < <(detect_configs)

local_available=()
local_already=()
for cfg in "${configs[@]}"; do
    if already_sourced "$cfg"; then
        local_already+=("$cfg")
    else
        local_available+=("$cfg")
    fi
done

if [ ${#local_already[@]} -gt 0 ]; then
    for cfg in "${local_already[@]}"; do
        info "Already sourced in ${BOLD}$cfg${RESET}  (skipped)"
    done
fi

if [ ${#local_available[@]} -eq 0 ]; then
    info "Bashgency is already loaded in all detected config files."
else
    echo ""
    printf "  ${CYAN}?${RESET} Select a config file to add Bashgency source lines:\n"
    echo ""
    PS3="  ${BOLD}Enter a number${RESET} (or ${YELLOW}0${RESET} to skip): "
    select cfg in "${local_available[@]}"; do
        if [ -n "$cfg" ]; then
            echo ""
            add_source_block "$cfg"
            break
        elif [ "$REPLY" = "0" ]; then
            echo ""
            warn "Skipped. Add these lines manually if you need:"
            echo ""
            echo "    $SOURCE_LINE"
            echo "    $SOURCE_LINE2"
            if ! grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
                echo "    $ALIASES_LINE"
                echo "    $ALIASES_LINE2"
            fi
            echo ""
            break
        else
            printf "  ${RED}${BOLD}x${RESET} Invalid option: ${BOLD}$REPLY${RESET}\n"
        fi
    done
fi
divider

# ---------------------------------------------------------------------------
# Source in current session
# ---------------------------------------------------------------------------
if [ "$IS_SOURCED" = true ]; then
    # Shell inherits the functions — source directly into it
    if [ -f "$MODULE_PATH" ]; then
        source "$MODULE_PATH"
        info "Sourced bashgency in current shell"
    fi
    if [ -f "$CONFIG_DIR/aliases.sh" ]; then
        source "$CONFIG_DIR/aliases.sh"
        info "Sourced aliases in current shell"
    fi
else
    # Executed as sub-shell — can't affect parent
    info "bashgency installed to disk"
    sub "Run this to activate in the current shell:"
    sub "  ${BOLD}source $MODULE_PATH${RESET}"
fi
divider

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
heading "Setup complete"
divider
echo ""
printf "  ${BOLD}Location${RESET}        Path\n"
printf "  ${DIM}------${RESET}        ${DIM}----${RESET}\n"
printf "  ${CYAN}Module${RESET}         %s\n" "$MODULE_PATH"
printf "  ${CYAN}Config${RESET}         %s\n" "$CONFIG_DIR/env"
printf "  ${CYAN}Aliases${RESET}        %s\n" "$CONFIG_DIR/aliases.sh"
echo ""
divider

if [ -f "$CONFIG_DIR/env" ]; then
    final_provider=$(__bashgency_env_get_provider "$CONFIG_DIR/env")
    if __bashgency_provider_key_ok_for "$final_provider" "$CONFIG_DIR/env"; then
        heading "API key is set. Ready to go!"
        sub "Provider: ${BOLD}${final_provider}${RESET} (override per run: ${BOLD}bashgency -P <provider>${RESET})"
    else
        heading "Next steps"
        divider
        echo ""
        printf "  ${BOLD}1.${RESET}  Edit ${CYAN}%s/env${RESET} — set ${BOLD}BASHGENCY_PROVIDER${RESET} and matching API key\n" "$CONFIG_DIR"
        echo ""
        printf "  ${BOLD}2.${RESET}  Reload your shell:\n"
        printf "       ${DIM}source ~/.zshrc${RESET}  (or ${DIM}source ~/.bashrc${RESET})\n"
        echo ""
        printf "  ${BOLD}3.${RESET}  Test it:\n"
        printf "       ${DIM}bashgency -p 'alias gst for git status' --preview${RESET}\n"
        printf "       ${DIM}bashgency -P deepseek -p '...' --preview${RESET}  ${DIM}(override provider)${RESET}\n"
        echo ""
        divider
    fi
fi
echo ""
sub "Tip: ${BOLD}BASHGENCY_PROVIDER${RESET} in env; override with ${BOLD}bashgency -P${RESET}; ${BOLD}BASHGENCY_TARGET${RESET} for alias destination"
echo ""
