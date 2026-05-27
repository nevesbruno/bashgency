#!/usr/bin/env bash

# Bashgency Uninstaller
# Removes all runtime traces without deleting the repo:
#   1. Remove source lines from .zshrc and .bashrc
#   2. Remove ~/.config/bashgency/ (env, aliases, history, backups, modules)
#   3. Verify no stale references remain

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  RED=$(tput setaf 1 2>/dev/null || echo '')
  GREEN=$(tput setaf 2 2>/dev/null || echo '')
  YELLOW=$(tput setaf 3 2>/dev/null || echo '')
  CYAN=$(tput setaf 6 2>/dev/null || echo '')
  BOLD=$(tput bold 2>/dev/null || echo '')
  DIM=$(tput dim 2>/dev/null || echo '')
  RESET=$(tput sgr0 2>/dev/null || echo '')
  SEP="${DIM}---${RESET}"
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''; SEP='---'
fi

info()    { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}○${RESET} %s\n" "$*"; }
err()     { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }
heading() { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }
sub()     { printf "  ${DIM}%s${RESET}\n" "$*"; }
divider() { printf "  ${SEP}\n"; }

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n"
printf "  ${BOLD}${RED}╔══════════════════════════════════════════════════╗${RESET}\n"
printf "  ${BOLD}${RED}║${RESET}               ${BOLD}Bashgency Uninstaller${RESET}           ${RED}║${RESET}\n"
printf "  ${BOLD}${RED}║${RESET}         Removes runtime, keeps repo intact        ${RED}║${RESET}\n"
printf "  ${BOLD}${RED}╚══════════════════════════════════════════════════╝${RESET}\n"
printf "\n"

CONFIG_DIR="${BASHGENCY_DIR:-$HOME/.config/bashgency}"

# ---------------------------------------------------------------------------
# Step 1/3 — Remove source lines from rc files
# ---------------------------------------------------------------------------
heading "> 1/3  ---  Shell rc files"
divider

remove_bashgency_block() {
    local file="$1"
    local label="$2"

    if [ ! -f "$file" ]; then
        warn "${BOLD}$label${RESET} not found  (skipped)"
        return
    fi

    if ! grep -q 'bashgency-cli.sh' "$file" 2>/dev/null; then
        info "No bashgency lines in ${BOLD}$label${RESET}  (clean)"
        return
    fi

    # Remove bashgency lines: comment header + 4 source lines
    sed -i '/bashgency-cli\.sh/d; /\.config\/bashgency\/aliases\.sh/d; /^# Bashgency$/d' "$file"
    # Clean up consecutive blank lines
    sed -i '/^[[:space:]]*$/N;/^\n[[:space:]]*$/D' "$file"

    info "Removed bashgency lines from ${BOLD}$label${RESET}"
}

remove_bashgency_block "$HOME/.bashrc" ".bashrc"
remove_bashgency_block "$HOME/.zshrc"  ".zshrc"
divider

# ---------------------------------------------------------------------------
# Step 2/3 — Remove runtime config directory
# ---------------------------------------------------------------------------
heading "> 2/3  ---  Runtime data"
divider

if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    info "Removed ${BOLD}$CONFIG_DIR${RESET}"
    sub "  env, aliases.sh, history, backups/, modules/, .initialized"
else
    warn "${BOLD}$CONFIG_DIR${RESET} not found  (clean)"
fi
divider

# ---------------------------------------------------------------------------
# Step 3/3 — Verify no stale references
# ---------------------------------------------------------------------------
heading "> 3/3  ---  Verification"
divider

stale=false

for file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$file" ] && grep -q 'bashgency-cli.sh' "$file" 2>/dev/null; then
        err "Stale reference in ${BOLD}$file${RESET}"
        stale=true
    fi
done

if [ -d "$CONFIG_DIR" ]; then
    err "Stale directory ${BOLD}$CONFIG_DIR${RESET}"
    stale=true
fi

if [ "$stale" = false ]; then
    info "All bashgency runtime traces removed"
fi
divider

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n"
heading "Done"
divider
printf "\n"
printf "  ${BOLD}Repo${RESET}        ${CYAN}~/lab/bashgency${RESET}  (kept)\n"
printf "\n"
printf "  ${YELLOW}○${RESET}  Reload your shell:\n"
printf "       ${DIM}source ~/.zshrc${RESET}  (or ${DIM}source ~/.bashrc${RESET})\n"
printf "\n"
printf "  ${YELLOW}○${RESET}  Reinstall later:\n"
printf "       ${DIM}source ~/lab/bashgency/install.sh${RESET}\n"
printf "\n"
divider
printf "\n"
