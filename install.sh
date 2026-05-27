#!/usr/bin/env bash
set -euo pipefail

# Bashgency Installer
# Steps:
#   1. Create config directory structure
#   2. Copy env.example (if not exists)
#   3. Create default aliases.sh (if needed)
#   4. Add source line to shell config (if desired)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${BASHGENCY_DIR:-$HOME/.config/bashgency}"
MODULE_PATH="$ROOT/modules/bashgency-cli.sh"

# --- Colors (from __bashgency_colors pattern) ---
if [ -t 1 ]; then
  RED=$(tput setaf 1 2>/dev/null || echo '')
  GREEN=$(tput setaf 2 2>/dev/null || echo '')
  YELLOW=$(tput setaf 3 2>/dev/null || echo '')
  BOLD=$(tput bold 2>/dev/null || echo '')
  RESET=$(tput sgr0 2>/dev/null || echo '')
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[*]${RESET} %s\n" "$*"; }
err()   { printf "${RED}[!]${RESET} %s\n" "$*" >&2; }

# ==============================================================
# Step 1 + 2: Config dir structure + env
# ==============================================================
info "Setting up Bashgency runtime in $CONFIG_DIR"

mkdir -p "$CONFIG_DIR/modules" "$CONFIG_DIR/backups"

if [ ! -f "$CONFIG_DIR/env" ]; then
    cp "$ROOT/env.example" "$CONFIG_DIR/env"
    chmod 600 "$CONFIG_DIR/env"
    info "Created $CONFIG_DIR/env -- edit it and set DEEPSEEK_API_KEY"
else
    warn "$CONFIG_DIR/env already exists (not overwritten)"
fi

# ==============================================================
# Step 3: Default aliases file
# ==============================================================
if ! grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
    if [ ! -f "$CONFIG_DIR/aliases.sh" ]; then
        touch "$CONFIG_DIR/aliases.sh"
        info "Created $CONFIG_DIR/aliases.sh (default aliases destination)"
    fi
fi

# ==============================================================
# Step 4: Load in shell (the actual step 3 from README)
# ==============================================================
# Lines to add
SOURCE_LINE='[ -f "$HOME/lab/bashgency/modules/bashgency-cli.sh" ] && \'
SOURCE_LINE2='  source "$HOME/lab/bashgency/modules/bashgency-cli.sh"'
ALIASES_LINE='[ -f "$HOME/.config/bashgency/aliases.sh" ] && \'
ALIASES_LINE2='  source "$HOME/.config/bashgency/aliases.sh"'

detect_configs() {
    local candidates=()
    # Zsh — respects ZDOTDIR
    local zdotdir="${ZDOTDIR:-$HOME}"
    [ -f "$zdotdir/.zshrc" ] && candidates+=("$zdotdir/.zshrc")
    # Bash
    [ -f "$HOME/.bashrc" ]    && candidates+=("$HOME/.bashrc")
    [ -f "$HOME/.bash_profile" ] && candidates+=("$HOME/.bash_profile")
    [ -f "$HOME/.profile" ]   && candidates+=("$HOME/.profile")
    # Default fallback: create .zshrc or .bashrc depending on $SHELL
    if [ ${#candidates[@]} -eq 0 ]; then
        case "${SHELL##*/}" in
            zsh) candidates+=("$zdotdir/.zshrc") ;;
            bash) candidates+=("$HOME/.bashrc") ;;
            *) candidates+=("$HOME/.zshrc") ;;
        esac
    fi
    printf '%s\n' "${candidates[@]}"
}

already_sourced() {
    local file="$1"
    if [ -f "$file" ]; then
        grep -qF 'bashgency-cli.sh' "$file" 2>/dev/null && return 0
    fi
    return 1
}

add_source_block() {
    local file="$1"
    local added=false

    {
        echo ""
        echo "# Bashgency"
        echo "$SOURCE_LINE"
        echo "$SOURCE_LINE2"
    } >> "$file"
    added=true

    # Also add aliases source, unless BASHGENCY_TARGET is set
    if ! grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
        {
            echo "$ALIASES_LINE"
            echo "$ALIASES_LINE2"
        } >> "$file"
    fi

    echo "" >> "$file"
    info "Added Bashgency source lines to $file"
}

# --- Interactive shell loader ---
echo ""
info "Shell integration (step 3: load bashgency in your shell)"

# Detect which config files exist (or would be created)
mapfile -t configs < <(detect_configs)

# Filter to those that DON'T already have the source
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
        warn "Bashgency already sourced in $cfg (skipping)"
    done
fi

if [ ${#local_available[@]} -eq 0 ]; then
    info "Bashgency is already loaded in all detected config files."
else
    PS3="Select config file to add Bashgency (or 0 to skip): "
    select cfg in "${local_available[@]}"; do
        if [ -n "$cfg" ]; then
            add_source_block "$cfg"
            break
        elif [ "$REPLY" = "0" ]; then
            warn "Skipped shell integration. Add manually:"
            echo "    $SOURCE_LINE"
            echo "    $SOURCE_LINE2"
            break
        else
            err "Invalid choice: $REPLY"
        fi
    done
fi

# ==============================================================
# Summary
# ==============================================================
echo ""
info "Setup complete."
echo ""
echo "  ${BOLD}Module:${RESET}     $MODULE_PATH"
echo "  ${BOLD}Config:${RESET}     $CONFIG_DIR/env"
echo "  ${BOLD}Aliases:${RESET}    $CONFIG_DIR/aliases.sh"
echo ""
echo "  ${BOLD}Next steps:${RESET}"
echo "  1. Edit $CONFIG_DIR/env and set DEEPSEEK_API_KEY"
echo "  2. Reload your shell: source ~/.zshrc (or ~/.bashrc)"
echo "  3. Test: bashgency -p 'alias gst for git status' --preview"
echo ""
echo "  ${BOLD}Override:${RESET}   BASHGENCY_TARGET in env changes aliases destination"
