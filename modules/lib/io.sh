#!/usr/bin/env bash
# io.sh - File operations (backup, history, writing aliases)
# Part of Bashgency

if [ -n "${__BASHGENCY_IO_LOADED:-}" ]; then
    return 0
fi

__bashgency_save_history() {
    local entry_type="$1"
    local entry_name="$2"
    local entry_description="$3"
    local timestamp
    timestamp=$(__bashgency_datetime)
    printf '%s | %s | %s | %s\n' "$timestamp" "$entry_type" "$entry_name" "$entry_description" >> "$BASHGENCY_HISTORY"
}

__bashgency_backup_aliases() {
    local timestamp
    timestamp=$(__bashgency_datetime "%Y%m%d_%H%M%S")
    local script_path
    script_path="$(__bashgency_aliases_path)"
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$BASHGENCY_BACKUP_DIR/zshrc_backup_$timestamp"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$BASHGENCY_BACKUP_DIR/bashrc_backup_$timestamp"
    fi
    if [ -f "$script_path" ]; then
        cp "$script_path" "$BASHGENCY_BACKUP_DIR/alias_backup_$timestamp.sh"
    fi
}

__bashgency_ensure_rc_sourcing() {
    local target_file="$1"
    local alias_script_path="$2"
    if ! grep -q "source.*$alias_script_path" "$target_file" 2>/dev/null; then
        {
            echo ""
            echo "# Load custom aliases"
            echo "[ -f \"$alias_script_path\" ] && source \"$alias_script_path\""
        } >> "$target_file"
        return 0
    fi
    return 0
}

__bashgency_reload_shell() {
    local alias_script_path="$1"
    if [ -n "${ZSH_VERSION:-}" ]; then
        source "$HOME/.zshrc" 2>/dev/null
    elif [ -n "${BASH_VERSION:-}" ]; then
        source "$HOME/.bashrc" 2>/dev/null
    fi
    [ -f "$alias_script_path" ] && source "$alias_script_path" 2>/dev/null
}

__BASHGENCY_IO_LOADED=1
