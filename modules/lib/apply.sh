#!/usr/bin/env bash
# apply.sh - Apply AI-generated aliases, functions and modules
# Part of Bashgency

if [ -n "${__BASHGENCY_APPLY_LOADED:-}" ]; then
    return 0
fi

# ---------- single entry handlers ----------

__bashgency_apply_alias() {
    local name="$1"
    local code="$2"
    local prompt="$3"
    local alias_script_path="$4"
    local target_file="$5"

    {
        echo ""
        printf '# [AI] %s - %s\n' "$(date +"%Y-%m-%d %H:%M")" "$prompt"
        echo "alias $name=\"$code\""
    } >> "$alias_script_path"

    __bashgency_ensure_rc_sourcing "$target_file" "$alias_script_path"

    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Alias '${F_CYAN}$name${RESET}' added!"
    __bashgency_save_history "alias" "$name" "$prompt"
}

__bashgency_apply_function() {
    local name="$1"
    local code="$2"
    local prompt="$3"
    local alias_script_path="$4"

    {
        echo ""
        printf '# [AI] %s - %s\n' "$(date +"%Y-%m-%d %H:%M")" "$prompt"
        echo "$code"
    } >> "$alias_script_path"

    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Function '${F_CYAN}$name${RESET}' added!"
    __bashgency_save_history "function" "$name" "$prompt"
}

__bashgency_apply_module() {
    local name="$1"
    local code="$2"
    local source_line="$3"
    local prompt="$4"
    local alias_script_path="$5"

    local mod_file="$BASHGENCY_MODULES_DIR/${name}.sh"
    echo "$code" > "$mod_file"
    chmod +x "$mod_file" 2>/dev/null

    {
        echo ""
        printf '# [AI] %s - Module: %s\n' "$(date +"%Y-%m-%d %H:%M")" "$name"
        echo "$source_line"
    } >> "$alias_script_path"

    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Module '${F_CYAN}$name${RESET}' created at ${F_BLUE}$mod_file${RESET}"
    __bashgency_save_history "module" "$name" "$prompt"
}

# ---------- entry state machine ----------

__bashgency_flush_entry() {
    local entry_type="$1" entry_name="$2" entry_code="$3" entry_source="$4"
    local prompt="$5" alias_script_path="$6" target_file="$7"

    [ -z "$entry_name" ] && return
    [ -z "$entry_code" ] && return

    case "$entry_type" in
        ALIAS)     __bashgency_apply_alias     "$entry_name" "$entry_code" "$prompt" "$alias_script_path" "$target_file" ;;
        FUNCTION)  __bashgency_apply_function  "$entry_name" "$entry_code" "$prompt" "$alias_script_path" ;;
        MODULE)    __bashgency_apply_module    "$entry_name" "$entry_code" "$entry_source" "$prompt" "$alias_script_path" ;;
    esac

    (( applied_count++ ))
    [ "$entry_type" = MODULE ] && (( module_count++ ))
}

# ---------- main apply ----------

__bashgency_apply_changes() {
    local prompt="$1"
    local ai_content="$2"

    __bashgency_backup_aliases

    local target_file
    if [ -f "$HOME/.zshrc" ]; then
        target_file="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        target_file="$HOME/.bashrc"
    else
        target_file="$HOME/.bashrc"
    fi

    local alias_script_path
    alias_script_path="$(__bashgency_aliases_path)"

    local line
    local applied_count=0 module_count=0 errors=0
    local in_multiline=false
    local entry_type="" entry_name="" entry_code="" entry_source=""

    apply_flush() {
        [ -z "$entry_name" ] && return
        [ -z "$entry_code" ] && return

        case "$entry_type" in
            ALIAS)
                __bashgency_apply_alias "$entry_name" "$entry_code" "$prompt" "$alias_script_path" "$target_file"
                ((applied_count++))
                ;;
            FUNCTION)
                __bashgency_apply_function "$entry_name" "$entry_code" "$prompt" "$alias_script_path"
                ((applied_count++))
                ;;
            MODULE)
                __bashgency_apply_module "$entry_name" "$entry_code" "$entry_source" "$prompt" "$alias_script_path"
                ((applied_count++))
                ((module_count++))
                ;;
        esac

        entry_type=""
        entry_name=""
        entry_code=""
        entry_source=""
        in_multiline=false
    }

    while IFS= read -r line || [ -n "$line" ]; do
        if echo "$line" | grep -qE "^(ALIAS|FUNCTION|MODULE) ::"; then
            [ -n "$entry_type" ] && apply_flush

            entry_type=$(__bashgency_parse_type "$line")
            entry_name=$(__bashgency_parse_field "$line" 2)
            entry_code=$(__bashgency_parse_field "$line" 3)
            entry_source=$(__bashgency_parse_field "$line" 4)

            case "$entry_type" in
                ALIAS)
                    apply_flush
                    ;;
                FUNCTION|MODULE)
                    if echo "$entry_code" | grep -q '{'; then
                        in_multiline=true
                        if echo "$line" | grep -qE '\}[[:space:]]*$'; then
                            apply_flush
                        fi
                    else
                        apply_flush
                    fi
                    ;;
            esac
        elif [ "$in_multiline" = true ]; then
            entry_code="${entry_code}"$'\n'"${line}"
            if echo "$line" | grep -qE '^[[:space:]]*\}[[:space:]]*$'; then
                apply_flush
            fi
        fi
    done <<EOF
$ai_content
EOF

    [ -n "$entry_type" ] && apply_flush

    echo ""
    __bashgency_box " SUMMARY "
    echo ""
    echo " ${F_GREEN}${applied_count}${RESET} item(s) applied"
    if [ "$module_count" -gt 0 ]; then
        echo " ${module_count} module(s) in ${F_BLUE}$BASHGENCY_MODULES_DIR${RESET}"
    fi
    if [ "$errors" -gt 0 ]; then
        echo " ${F_RED}${errors} error(s)${RESET}"
    fi
    echo ""

    echo " ${F_YELLOW}${BOLD}[~]${RESET} Reloading shell..."
    __bashgency_reload_shell "$alias_script_path"

    echo " ${F_GREEN}${BOLD}[ OK ]${RESET} Done! Your new alias/function is ready."
    __bashgency_farewell
    echo " ${F_CYAN}Tip:${RESET} Use ${F_GREEN}bashgency -p \"description\"${RESET} for direct mode."
    echo " ${F_CYAN}Tip:${RESET} Use ${F_GREEN}bashgency -h${RESET} for full help."
    echo ""
}

__BASHGENCY_APPLY_LOADED=1
