#!/usr/bin/env bash
#
# inventory.sh - Interactive inventory browser for aliases/functions/modules
# Part of Bashgency
#
# Displays a categorized, navigable TUI of all generated items.
# Data sources: history log, aliases file, modules directory.
#
# NOTE: All functions here run under zsh 'emulate sh' (called from bashgency()),
# so avoid bashisms: no ${!array[@]}, no ((...)) statements, no [[ ]] (use [ ]).

if [ -n "${__BASHGENCY_INVENTORY_LOADED:-}" ]; then
    return 0
fi

# ---------- data model: parallel arrays ----------

__inventory_types=()        # ALIAS | FUNCTION | MODULE
__inventory_names=()        # entry name
__inventory_descs=()        # description
__inventory_codes=()        # code snippet
__inventory_dates=()        # creation date

__inventory_filtered=()     # indices into the above arrays
__inventory_selected=0      # currently selected index in filtered list
__inventory_filter=""       # active search filter
__inventory_category="ALL"  # ALL | ALIAS | FUNCTION | MODULE

# ---------- helpers ----------

__inventory_clear_state() {
    __inventory_types=()
    __inventory_names=()
    __inventory_descs=()
    __inventory_codes=()
    __inventory_dates=()
    __inventory_filtered=()
    __inventory_selected=0
    __inventory_filter=""
    __inventory_category="ALL"
}

__inventory_badge() {
    local type="$1"
    case "$type" in
        ALIAS)    printf "${F_GREEN}${BOLD}ALIAS${RESET}" ;;
        FUNCTION) printf "${F_YELLOW}${BOLD}FUNC${RESET}" ;;
        MODULE)   printf "${F_MAGENTA}${BOLD}MODL${RESET}" ;;
        *)        printf "${F_DIM}????${RESET}" ;;
    esac
}

__inventory_color_for_type() {
    local type="$1"
    case "$type" in
        ALIAS)    printf '%s' "$F_GREEN" ;;
        FUNCTION) printf '%s' "$F_YELLOW" ;;
        MODULE)   printf '%s' "$F_MAGENTA" ;;
        *)        printf '%s' "$F_WHITE" ;;
    esac
}

# ---------- portable single-key read ----------
# read -n1 (bash) vs read -k1 (zsh, needed under emulate sh)
__bashgency_read_key() {
    local var="" timeout=""
    # Parse: [ -t N ] varname
    if [ "$1" = "-t" ] && [ -n "$2" ]; then
        timeout="$2"
        var="$3"
    else
        var="$1"
    fi

    if [ -n "${ZSH_VERSION:-}" ]; then
        if [ -n "$timeout" ]; then
            read -s -k1 -t "$timeout" "$var"
        else
            read -s -k1 "$var"
        fi
    else
        if [ -n "$timeout" ]; then
            read -s -n1 -t "$timeout" "$var"
        else
            read -s -n1 "$var"
        fi
    fi
}

# ---------- iteration helper (posix-safe array iteration) ----------

# Usage: __inventory_iter <callback_fn>
# Calls callback_fn with <idx> <count> for each element in the master arrays
__inventory_iter() {
    local fn="$1" i=0 count
    count=${#__inventory_types[@]}
    while [ "$i" -lt "$count" ]; do
        "$fn" "$i" "$count"
        i=$((i + 1))
    done
}

__inventory_iter_filtered() {
    local fn="$1" i=0 count
    count=${#__inventory_filtered[@]}
    while [ "$i" -lt "$count" ]; do
        "$fn" "$i" "$count"
        i=$((i + 1))
    done
}

# ---------- data loading ----------

__bashgency_inventory_load() {
    __inventory_clear_state

    local hist_file="$BASHGENCY_HISTORY"
    local alias_file
    alias_file="$(__bashgency_aliases_path)"

    # --- Parse history file (authoritative source for metadata) ---
    if [ -f "$hist_file" ]; then
        local hist_item_count=0
        while IFS='|' read -r ts etype ename edesc; do
            ts="$(printf '%s' "$ts" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            etype="$(printf '%s' "$etype" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
            ename="$(printf '%s' "$ename" | tr -d '[:space:]')"
            edesc="$(printf '%s' "$edesc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            case "$etype" in
                ALIAS|FUNCTION|MODULE) ;;
                *) continue ;;
            esac
            [ -z "$ename" ] && continue

            __inventory_types+=("$etype")
            __inventory_names+=("$ename")
            __inventory_descs+=("$edesc")
            __inventory_dates+=("${ts%% *}")
            __inventory_codes+=("")
            hist_item_count=$((hist_item_count + 1))
        done < "$hist_file"

        if [ "$hist_item_count" -eq 0 ]; then
            __bashgency_inventory_parse_aliases_file "$alias_file"
        else
            __bashgency_inventory_extract_codes "$alias_file"
        fi
    else
        __bashgency_inventory_parse_aliases_file "$alias_file"
    fi

    __bashgency_inventory_scan_modules
    __inventory_apply_filter
}

# Fallback: parse aliases file directly when no history exists
__bashgency_inventory_parse_aliases_file() {
    local file="$1"
    [ ! -f "$file" ] && return

    local current_desc="" current_type="" current_code=""
    local in_function=false in_multiline=false

    while IFS= read -r line || [ -n "$line" ]; do
        if echo "$line" | grep -qE '^[[:space:]]*#'; then
            local comment
            comment=$(printf '%s' "$line" | sed 's/^[[:space:]]*#[[:space:]]*//')
            if echo "$comment" | grep -qE '^\[AI\]'; then
                current_desc=$(printf '%s' "$comment" | sed 's/^\[AI\][[:space:]]*[0-9 :-]*[[:space:]]*-[[:space:]]*//')
            fi
            continue
        fi

        echo "$line" | grep -qE '^[[:space:]]*$' && continue
        echo "$line" | grep -qE '^[[:space:]]*source[[:space:]]' && continue

        if echo "$line" | grep -qE '^[[:space:]]*alias[[:space:]]+'; then
            local aname acode
            aname=$(printf '%s' "$line" | sed 's/^[[:space:]]*alias[[:space:]]*//;s/=.*//')
            acode=$(printf '%s' "$line" | sed 's/^[[:space:]]*alias[[:space:]]*[^=]*=//;s/^["\x27]//;s/["\x27]$//')
            aname=$(printf '%s' "$aname" | tr -d '[:space:]')

            __inventory_types+=("ALIAS")
            __inventory_names+=("$aname")
            __inventory_descs+=("${current_desc:-$(printf '%s' "$acode" | head -c 60)}")
            __inventory_codes+=("alias $aname=\"$acode\"")
            __inventory_dates+=("")
            current_desc=""
            continue
        fi

        if echo "$line" | grep -qE '^[[:space:]]*function[[:space:]]+|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)'; then
            local fname
            fname=$(printf '%s' "$line" | sed 's/^[[:space:]]*function[[:space:]]*//;s/[[:space:]]*().*$//;s/[[:space:]]*{$//')
            fname=$(printf '%s' "$fname" | tr -d '[:space:]')
            [ -z "$fname" ] && continue

            in_function=true
            current_type="FUNCTION"
            current_code="$line"
            continue
        fi

        if [ "$in_function" = true ]; then
            current_code="${current_code}"$'\n'"${line}"
            if echo "$line" | grep -qE '^[[:space:]]*\}[[:space:]]*$'; then
                __inventory_types+=("FUNCTION")
                __inventory_names+=("$fname")
                __inventory_descs+=("${current_desc:-$fname}")
                __inventory_codes+=("$current_code")
                __inventory_dates+=("")
                in_function=false
                current_code=""
                current_desc=""
            fi
        fi
    done < "$file"
}

# Extract code snippets for each entry from aliases file
__bashgency_inventory_extract_codes() {
    local file="$1"
    [ ! -f "$file" ] && return

    local i=0 count
    count=${#__inventory_names[@]}
    while [ "$i" -lt "$count" ]; do
        local name="${__inventory_names[$i]}"
        local type="${__inventory_types[$i]}"

        if [ "$type" != "MODULE" ]; then
            local found=false in_target=false brace_depth=0 code=""

            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$in_target" = false ]; then
                    if [ "$type" = "ALIAS" ] && echo "$line" | grep -qE "^[[:space:]]*alias[[:space:]]+${name}="; then
                        code="$line"
                        found=true
                        break
                    fi
                    if [ "$type" = "FUNCTION" ] && \
                        (echo "$line" | grep -qE "^[[:space:]]*function[[:space:]]+${name}[[:space:]]*\{?" || \
                         echo "$line" | grep -qE "^[[:space:]]*${name}[[:space:]]*\(\)"); then
                        in_target=true
                        code="$line"
                        brace_depth=1
                    fi
                else
                    code="${code}"$'\n'"${line}"
                    if echo "$line" | grep -qE '\{'; then
                        brace_depth=$((brace_depth + 1))
                    fi
                    if echo "$line" | grep -qE '\}'; then
                        brace_depth=$((brace_depth - 1))
                    fi
                    if [ "$brace_depth" -le 0 ]; then
                        found=true
                        break
                    fi
                fi
            done < "$file"

            if [ "$found" = true ]; then
                __inventory_codes[$i]="$code"
            fi
        fi

        i=$((i + 1))
    done
}

# Scan modules directory, adding any modules not already in inventory
__bashgency_inventory_scan_modules() {
    [ ! -d "$BASHGENCY_MODULES_DIR" ] && return

    # zsh-safe: prevent nomatch error when no .sh files exist
    setopt localoptions nonomatch 2>/dev/null || true

    local mod_file
    for mod_file in "$BASHGENCY_MODULES_DIR"/*.sh; do
        [ -f "$mod_file" ] || continue
        local modname
        modname=$(basename "$mod_file" .sh)

        local found=false j=0 jcount
        jcount=${#__inventory_names[@]}
        while [ "$j" -lt "$jcount" ]; do
            if [ "${__inventory_types[$j]}" = "MODULE" ] && [ "${__inventory_names[$j]}" = "$modname" ]; then
                __inventory_codes[$j]=$(cat "$mod_file")
                found=true
                break
            fi
            j=$((j + 1))
        done

        if [ "$found" = false ]; then
            __inventory_types+=("MODULE")
            __inventory_names+=("$modname")
            __inventory_descs+=("Module: $modname")
            __inventory_codes+=("$(head -c 200 "$mod_file")")
            __inventory_dates+=("$(stat -c '%Y' "$mod_file" 2>/dev/null | xargs -I{} date -d '@{}' '+%Y-%m-%d' 2>/dev/null || echo '')")
        fi
    done
}

# ---------- filtering ----------

__inventory_apply_filter() {
    __inventory_filtered=()
    __inventory_selected=0

    local i=0 count
    count=${#__inventory_types[@]}
    while [ "$i" -lt "$count" ]; do
        if [ "$__inventory_category" = "ALL" ] || [ "${__inventory_types[$i]}" = "$__inventory_category" ]; then
            if [ -z "$__inventory_filter" ]; then
                __inventory_filtered+=("$i")
            else
                local haystack
                haystack="${__inventory_names[$i]} ${__inventory_descs[$i]}"
                if echo "$haystack" | grep -qi "$__inventory_filter"; then
                    __inventory_filtered+=("$i")
                fi
            fi
        fi
        i=$((i + 1))
    done
}

# ---------- rendering ----------

__bashgency_inventory_render() {
    clear

    local total alias_count func_count mod_count
    total=${#__inventory_types[@]}
    alias_count=0; func_count=0; mod_count=0

    local ri=0 rcount
    rcount=${#__inventory_types[@]}
    while [ "$ri" -lt "$rcount" ]; do
        case "${__inventory_types[$ri]}" in
            ALIAS)    alias_count=$((alias_count + 1)) ;;
            FUNCTION) func_count=$((func_count + 1)) ;;
            MODULE)   mod_count=$((mod_count + 1)) ;;
        esac
        ri=$((ri + 1))
    done

    local filtered_count=${#__inventory_filtered[@]}

    __bashgency_box " BASHGENCY INVENTORY "
    echo ""
    printf "  ${F_CYAN}%s${RESET}  ${F_GREEN}%s${RESET}  ${F_YELLOW}%s${RESET}  ${F_MAGENTA}%s${RESET}\n" \
        "TOTAL: $total" "ALIAS: $alias_count" "FUNC: $func_count" "MOD: $mod_count"
    echo ""

    # --- Category tabs ---
    local tabs=""
    for cat in ALL ALIAS FUNCTION MODULE; do
        if [ "$cat" = "$__inventory_category" ]; then
            tabs="${tabs} ${F_BLACK}${B_WHITE} ${cat} ${RESET} "
        else
            tabs="${tabs} ${F_DIM}${cat}${RESET} "
        fi
    done
    printf "  %s\n\n" "$tabs"

    # --- Search bar ---
    if [ -n "$__inventory_filter" ]; then
        printf "  ${F_YELLOW}/%s${RESET}\n\n" "$__inventory_filter"
    fi

    # --- Item list ---
    local visible_count=$filtered_count
    local max_visible
    max_visible=$(tput lines 2>/dev/null || echo 24)
    max_visible=$((max_visible - 12))
    [ "$max_visible" -lt 5 ] && max_visible=5

    local start_idx=0
    if [ "$__inventory_selected" -ge "$((max_visible - 1))" ]; then
        start_idx=$((__inventory_selected - max_visible + 1))
    fi
    local end_idx=$((start_idx + max_visible))
    [ "$end_idx" -gt "$visible_count" ] && end_idx=$visible_count

    local panel_w=64

    printf "  ${F_CYAN}+"
    __bashgency_repeat "-" "$((panel_w - 2))"
    printf "+${RESET}\n"

    if [ "$visible_count" -eq 0 ]; then
        printf "  ${F_CYAN}|${RESET}  ${F_DIM}%s${RESET}\n" "No items found."
        printf "  ${F_CYAN}|${RESET}  ${F_DIM}%s${RESET}\n" 'Create aliases/functions with: bashgency -p "desc"'
        printf "  ${F_CYAN}+"
        __bashgency_repeat "-" "$((panel_w - 2))"
        printf "+${RESET}\n"
        return
    fi

    local pos=$start_idx
    while [ "$pos" -lt "$end_idx" ]; do
        local idx="${__inventory_filtered[$pos]}"
        local name="${__inventory_names[$idx]}"
        local desc="${__inventory_descs[$idx]}"
        local type="${__inventory_types[$idx]}"
        local badge type_color name_display desc_display

        badge=$(__inventory_badge "$type")
        type_color=$(__inventory_color_for_type "$type")
        name_display=$(__bashgency_trunc "$name" 22)
        desc_display=$(__bashgency_trunc "$desc" 32)

        if [ "$pos" -eq "$__inventory_selected" ]; then
            printf "  ${F_CYAN}|${RESET}${B_CYAN}${F_BLACK} >> ${name_display}  ${badge}  ${desc_display}${RESET}"
            local pad_len=$((panel_w - 6 - ${#name_display} - 4 - 10 - ${#desc_display} - 4))
            [ "$pad_len" -lt 0 ] && pad_len=0
            __bashgency_repeat " " "$pad_len"
            printf "${RESET}\n"
        else
            printf "  ${F_CYAN}|${RESET}     ${type_color}${name_display}${RESET}"
            local pad1=$((22 - ${#name_display}))
            [ "$pad1" -lt 0 ] && pad1=0
            __bashgency_repeat " " "$pad1"
            printf " ${badge} "
            local pad2=$((26 - ${#desc_display}))
            [ "$pad2" -lt 0 ] && pad2=0
            printf "${F_DIM}${desc_display}${RESET}"
            __bashgency_repeat " " "$pad2"
            printf "\n"
        fi
        pos=$((pos + 1))
    done

    printf "  ${F_CYAN}+"
    __bashgency_repeat "-" "$((panel_w - 2))"
    printf "+${RESET}\n"

    echo ""
    printf "  ${F_GREEN}[j/k]${RESET} nav  ${F_CYAN}[1/2/3]${RESET} filter  ${F_CYAN}[a]${RESET} all  ${F_CYAN}[/]${RESET} search  ${F_YELLOW}[Enter]${RESET} details  ${F_RED}[q]${RESET} quit\n"
    if [ "$visible_count" -gt 0 ]; then
        printf "  ${F_DIM}Showing %d-%d of %d${RESET}\n" "$((start_idx + 1))" "$end_idx" "$visible_count"
    fi
    echo ""
}

# ---------- detail view ----------

__bashgency_inventory_detail() {
    local idx="$1"
    local name="${__inventory_names[$idx]}"
    local type="${__inventory_types[$idx]}"
    local desc="${__inventory_descs[$idx]}"
    local code="${__inventory_codes[$idx]}"
    local date="${__inventory_dates[$idx]}"
    local badge
    badge=$(__inventory_badge "$type")

    clear
    __bashgency_box " DETAIL: ${name} "

    echo ""
    printf "  ${F_CYAN}Name${RESET}        ${F_WHITE}${BOLD}%s${RESET}\n" "$name"
    printf "  ${F_CYAN}Type${RESET}        %s\n" "$badge"
    [ -n "$date" ] && printf "  ${F_CYAN}Created${RESET}     %s\n" "$date"
    printf "  ${F_CYAN}Description${RESET} ${F_DIM}%s${RESET}\n" "$desc"
    echo ""

    if [ -n "$code" ]; then
        local line_count
        line_count=$(printf '%s' "$code" | wc -l)
        local term_height
        term_height=$(tput lines 2>/dev/null || echo 24)
        local max_lines=$((term_height - 14))
        [ "$max_lines" -lt 5 ] && max_lines=5

        __bashgency_panel_top "code (${line_count} lines)"
        local line_num=0
        while IFS= read -r codeline || [ -n "$codeline" ]; do
            line_num=$((line_num + 1))
            if [ "$line_num" -gt "$max_lines" ]; then
                printf "  ${F_CYAN}|${RESET}  ${F_DIM}... (%d more lines)${RESET}\n" "$((line_count - max_lines))"
                break
            fi
            __bashgency_panel_row "  ${F_DIM}${line_num}${RESET} ${F_WHITE}${codeline}${RESET}"
        done <<EOF
$code
EOF
        __bashgency_panel_bottom
    fi

    echo ""
    printf "  ${F_YELLOW}[Enter]${RESET} back to list  ${F_RED}[q]${RESET} quit\n"
    echo ""
}

# ---------- search mode ----------

__bashgency_inventory_search_mode() {
    echo -ne "  ${F_YELLOW}Search:${RESET} "
    read -r search_input
    __inventory_filter="$search_input"
    __inventory_apply_filter
    __inventory_selected=0
}

# ---------- main handler ----------

__bashgency_inventory_handle_input() {
    local key next dir
    __bashgency_read_key key

    case "$key" in
        j|J|$'\x1b')
            if [ "$key" = $'\x1b' ]; then
                __bashgency_read_key -t 0.1 next
                if [ "$next" = '[' ]; then
                    __bashgency_read_key -t 0.1 dir
                    case "$dir" in
                        A)  [ "$__inventory_selected" -gt 0 ] && __inventory_selected=$((__inventory_selected - 1)) ;;
                        B)  [ "$__inventory_selected" -lt "$(( ${#__inventory_filtered[@]} - 1 ))" ] && __inventory_selected=$((__inventory_selected + 1)) ;;
                    esac
                fi
            else
                [ "$__inventory_selected" -lt "$(( ${#__inventory_filtered[@]} - 1 ))" ] && __inventory_selected=$((__inventory_selected + 1))
            fi
            ;;
        k|K)
            [ "$__inventory_selected" -gt 0 ] && __inventory_selected=$((__inventory_selected - 1))
            ;;

        1) __inventory_category="ALIAS";    __inventory_apply_filter ;;
        2) __inventory_category="FUNCTION"; __inventory_apply_filter ;;
        3) __inventory_category="MODULE";   __inventory_apply_filter ;;
        a|A)
            __inventory_category="ALL"
            __inventory_filter=""
            __inventory_apply_filter
            ;;

        /|s|S)
            __bashgency_inventory_search_mode
            ;;

        c|C)
            __inventory_filter=""
            __inventory_apply_filter
            ;;

        '')
            local icount=${#__inventory_filtered[@]}
            if [ "$icount" -gt 0 ] && [ "$__inventory_selected" -lt "$icount" ]; then
                local real_idx="${__inventory_filtered[$__inventory_selected]}"
                __bashgency_inventory_detail "$real_idx"
                while true; do
                    __bashgency_read_key detail_key
                    case "$detail_key" in
                        ''|q|Q|$'\x1b') break ;;
                    esac
                done
            fi
            ;;

        q|Q)
            echo ""
            echo " ${F_DIM}Exiting inventory...${RESET}"
            sleep 0.3
            return 2
            ;;
    esac
    return 0
}

# ---------- public entry point ----------

__bashgency_inventory() {
    __bashgency_inventory_load

    local total=${#__inventory_types[@]}
    if [ "$total" -eq 0 ]; then
        clear
        __bashgency_box " BASHGENCY INVENTORY "
        echo ""
        echo " ${F_YELLOW}${BOLD}[!]${RESET} No aliases, functions, or modules found."
        echo ""
        echo " ${F_DIM}Create your first one:${RESET}"
        echo '   bashgency -p "alias to list git branches"'
        echo ""
        echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} Press Enter to continue "
        read -r
        return
    fi

    while true; do
        __bashgency_inventory_render
        __bashgency_inventory_handle_input
        local rc=$?
        [ "$rc" -eq 2 ] && break
    done
}

__BASHGENCY_INVENTORY_LOADED=1
