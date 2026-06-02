#!/usr/bin/env bash

# Bashgency Uninstaller
# Removes shell integration + ~/.config/bashgency; optional repo removal.
#
#   ./uninstall.sh
#   ./uninstall.sh --remove-repo -y
#   ./uninstall.sh --keep-repo -y

# ---------------------------------------------------------------------------
# Resolve repo root (bash/zsh)
# ---------------------------------------------------------------------------
if [ -n "${BASH_SOURCE+x}" ]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
else
    ROOT="$(cd "$(dirname "$0")" && pwd 2>/dev/null)"
fi

IS_SOURCED=false
if [ -n "${BASH_SOURCE+x}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ] && IS_SOURCED=true || true
else
    case "$0" in -zsh|zsh|bash|-bash|sh|-sh) ;; *) IS_SOURCED=true ;; esac
fi

# ---------------------------------------------------------------------------
# Colors (prefixed — avoids clash with bashgency readonly BOLD/RESET)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  _BG_UN_RED=$(tput setaf 1 2>/dev/null || echo '')
  _BG_UN_GREEN=$(tput setaf 2 2>/dev/null || echo '')
  _BG_UN_YELLOW=$(tput setaf 3 2>/dev/null || echo '')
  _BG_UN_CYAN=$(tput setaf 6 2>/dev/null || echo '')
  _BG_UN_BOLD=$(tput bold 2>/dev/null || echo '')
  _BG_UN_DIM=$(tput dim 2>/dev/null || echo '')
  _BG_UN_RESET=$(tput sgr0 2>/dev/null || echo '')
  _BG_UN_SEP="${_BG_UN_DIM}---${_BG_UN_RESET}"
else
  _BG_UN_RED=''; _BG_UN_GREEN=''; _BG_UN_YELLOW=''; _BG_UN_CYAN=''
  _BG_UN_BOLD=''; _BG_UN_DIM=''; _BG_UN_RESET=''; _BG_UN_SEP='---'
fi

info()    { printf "  ${_BG_UN_GREEN}✓${_BG_UN_RESET} %s\n" "$*"; }
warn()    { printf "  ${_BG_UN_YELLOW}○${_BG_UN_RESET} %s\n" "$*"; }
err()     { printf "  ${_BG_UN_RED}✗${_BG_UN_RESET} %s\n" "$*" >&2; }
heading() { printf "\n${_BG_UN_BOLD}${_BG_UN_CYAN}%s${_BG_UN_RESET}\n" "$*"; }
sub()     { printf "  ${_BG_UN_DIM}%s${_BG_UN_RESET}\n" "$*"; }
divider() { printf "  ${_BG_UN_SEP}\n"; }

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
ASSUME_YES=false
REMOVE_REPO=false
MODE_CHOSEN=false

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=true ;;
        --remove-repo) REMOVE_REPO=true; MODE_CHOSEN=true ;;
        --keep-repo)   REMOVE_REPO=false; MODE_CHOSEN=true ;;
        -h|--help)
            cat <<'EOF'
Bashgency uninstall

  ./uninstall.sh                 Interactive menu + confirmation
  ./uninstall.sh --keep-repo -y  Runtime only (keeps clone)
  ./uninstall.sh --remove-repo -y  Also deletes repository directory

Prefer: ./uninstall.sh or bash uninstall.sh (do not source)
EOF
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

if [ -n "${BASHGENCY_REMOVE_REPO+x}" ]; then
    case "${BASHGENCY_REMOVE_REPO}" in
        1|true|yes|YES) REMOVE_REPO=true; MODE_CHOSEN=true ;;
        0|false|no|NO) REMOVE_REPO=false; MODE_CHOSEN=true ;;
    esac
fi

CONFIG_DIR="${BASHGENCY_DIR:-$HOME/.config/bashgency}"

__bg_un_detect_rc_files() {
    local zdotdir="${ZDOTDIR:-$HOME}"
    local f
    for f in \
        "$zdotdir/.zshrc" \
        "$HOME/.bashrc" \
        "$HOME/.bash_profile" \
        "$HOME/.profile"
    do
        [ -f "$f" ] && printf '%s\n' "$f"
    done
}

__bg_un_rc_has_bashgency() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -qE 'bashgency|Bashgency' "$file" 2>/dev/null
}

__bg_un_clean_rc_file() {
    local file="$1"
    local label="$2"
    local tmp

    if [ ! -f "$file" ]; then
        warn "${_BG_UN_BOLD}${label}${_BG_UN_RESET} not found  (skipped)"
        return 0
    fi

    if ! __bg_un_rc_has_bashgency "$file"; then
        info "No bashgency references in ${_BG_UN_BOLD}${label}${_BG_UN_RESET}  (clean)"
        return 0
    fi

    tmp="${file}.bashgency-uninstall.$$"
    awk '
        /^# >>> Bashgency/ { skip=1; next }
        /^# <<< Bashgency/ { skip=0; next }
        skip { next }
        /^# Bashgency$/ { next }
        /bashgency-cli\.sh/ { next }
        /\.config\/bashgency/ { next }
        /lab\/bashgency\// { next }
        /\$HOME\/lab\/bashgency/ { next }
        /_BASHGENCY_MODULE/ { next }
        { print }
    ' "$file" > "$tmp"

    sed -i '/^[[:space:]]*$/N;/^\n[[:space:]]*$/D' "$tmp" 2>/dev/null || \
        sed -i '' '/^[[:space:]]*$/N;/^\n[[:space:]]*$/D' "$tmp" 2>/dev/null || true

    mv "$tmp" "$file"
    info "Removed bashgency block from ${_BG_UN_BOLD}${label}${_BG_UN_RESET}"
}

__bg_un_confirm() {
    local prompt="$1"
    local answer
    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        warn "Non-interactive shell: use -y to proceed without prompts"
        return 1
    fi
    printf "  ${_BG_UN_CYAN}?${_BG_UN_RESET} %s ${_BG_UN_DIM}[y/N]${_BG_UN_RESET} " "$prompt"
    read -r answer </dev/tty 2>/dev/null || read -r answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

__bg_un_choose_mode() {
    if [ "$MODE_CHOSEN" = true ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        REMOVE_REPO=false
        return 0
    fi
    printf "\n"
    printf "  ${_BG_UN_CYAN}?${_BG_UN_RESET} Select uninstall mode:\n\n"
    printf "    ${_BG_UN_BOLD}1${_BG_UN_RESET}  With repository    ${_BG_UN_DIM}(delete %s)${_BG_UN_RESET}\n" "$ROOT"
    printf "    ${_BG_UN_BOLD}2${_BG_UN_RESET}  Without repository ${_BG_UN_DIM}(keep clone)${_BG_UN_RESET}\n\n"
    printf "  ${_BG_UN_CYAN}?${_BG_UN_RESET} Choice [1-2] (default 2): "
    local choice
    read -r choice </dev/tty 2>/dev/null || read -r choice
    case "$choice" in
        1) REMOVE_REPO=true ;;
        *) REMOVE_REPO=false ;;
    esac
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n"
printf "  ${_BG_UN_BOLD}${_BG_UN_RED}╔══════════════════════════════════════════════════╗${_BG_UN_RESET}\n"
printf "  ${_BG_UN_BOLD}${_BG_UN_RED}║${_BG_UN_RESET}               ${_BG_UN_BOLD}Bashgency Uninstaller${_BG_UN_RESET}           ${_BG_UN_RED}║${_BG_UN_RESET}\n"
printf "  ${_BG_UN_BOLD}${_BG_UN_RED}║${_BG_UN_RESET}     Shell hooks + config; repo removal optional     ${_BG_UN_RED}║${_BG_UN_RESET}\n"
printf "  ${_BG_UN_BOLD}${_BG_UN_RED}╚══════════════════════════════════════════════════╝${_BG_UN_RESET}\n"
printf "\n"

if [ "$IS_SOURCED" = true ]; then
    warn "Script was sourced. Prefer: ${_BG_UN_BOLD}./uninstall.sh${_BG_UN_RESET}"
fi

__bg_un_choose_mode

# ---------------------------------------------------------------------------
# Removal plan
# ---------------------------------------------------------------------------
heading "Removal plan"
divider

rc_files=()
while IFS= read -r line; do
    [ -n "$line" ] && rc_files+=("$line")
done < <(__bg_un_detect_rc_files)

for f in "${rc_files[@]}"; do
    if __bg_un_rc_has_bashgency "$f"; then
        sub "  rc: $f"
    fi
done

if [ -d "$CONFIG_DIR" ]; then
    sub "  config: $CONFIG_DIR"
else
    sub "  config: (not present)"
fi

if [ "$REMOVE_REPO" = true ]; then
    sub "  repo:   $ROOT"
fi

if [ -f "$CONFIG_DIR/env" ] && grep -q '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
    target=$(grep -E '^BASHGENCY_TARGET=' "$CONFIG_DIR/env" | head -1 | cut -d= -f2- | tr -d "\"'")
    warn "BASHGENCY_TARGET set — aliases in ${_BG_UN_BOLD}${target}${_BG_UN_RESET} are NOT removed"
fi
divider

if ! __bg_un_confirm "Proceed with uninstall?"; then
    warn "Cancelled."
    return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------
# Step 1 — Shell rc files
# ---------------------------------------------------------------------------
heading "> 1/3  ---  Shell rc files"
divider

for f in "${rc_files[@]}"; do
    __bg_un_clean_rc_file "$f" "$(basename "$f")"
done
divider

# ---------------------------------------------------------------------------
# Step 2 — Runtime config
# ---------------------------------------------------------------------------
heading "> 2/3  ---  Runtime data"
divider

if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    info "Removed ${_BG_UN_BOLD}${CONFIG_DIR}${_BG_UN_RESET}"
    sub "  env, aliases, history, backups/, modules/, .initialized"
else
    warn "${_BG_UN_BOLD}${CONFIG_DIR}${_BG_UN_RESET} not found  (clean)"
fi
divider

# ---------------------------------------------------------------------------
# Step 3 — Repository (optional)
# ---------------------------------------------------------------------------
heading "> 3/3  ---  Repository"
divider

if [ "$REMOVE_REPO" = true ]; then
    if [ -d "$ROOT" ]; then
        if rm -rf "$ROOT"; then
            info "Removed ${_BG_UN_BOLD}${ROOT}${_BG_UN_RESET}"
        else
            err "Failed to delete ${ROOT}"
        fi
    else
        warn "Repository not found at ${_BG_UN_BOLD}${ROOT}${_BG_UN_RESET}"
    fi
else
    info "Repository kept at ${_BG_UN_BOLD}${ROOT}${_BG_UN_RESET}"
    sub "  Reinstall: bash ${ROOT}/install.sh"
fi
divider

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
heading "Verification"
divider

stale=false
for f in "${rc_files[@]}"; do
    if __bg_un_rc_has_bashgency "$f"; then
        err "Stale reference in ${_BG_UN_BOLD}$f${_BG_UN_RESET}"
        stale=true
    fi
done

if [ -d "$CONFIG_DIR" ]; then
    err "Stale directory ${_BG_UN_BOLD}${CONFIG_DIR}${_BG_UN_RESET}"
    stale=true
fi

if [ "$stale" = false ]; then
    info "Shell/config cleanup OK"
fi
divider

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n"
heading "Done"
divider
printf "\n"
if [ "$REMOVE_REPO" = true ] && [ ! -d "$ROOT" ]; then
    printf "  ${_BG_UN_BOLD}Repo${_BG_UN_RESET}        removed\n"
else
    printf "  ${_BG_UN_BOLD}Repo${_BG_UN_RESET}        ${_BG_UN_CYAN}%s${_BG_UN_RESET}\n" "$ROOT"
fi
printf "\n"
printf "  ${_BG_UN_YELLOW}○${_BG_UN_RESET}  Open a new shell (or reload rc) so bashgency commands unload\n"
printf "\n"
divider
printf "\n"

return 0 2>/dev/null || exit 0
