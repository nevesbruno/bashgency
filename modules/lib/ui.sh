#!/usr/bin/env bash
#
# ui.sh - UI rendering components (boxes, panels, menus, farewell)
# Part of Bashgency
#

# Guard
if [ -n "${__BASHGENCY_UI_LOADED:-}" ]; then
    return 0
fi

# ---------- helpers ----------

__bashgency_trunc() {
    local text="$1"
    local max="$2"
    if [ "${#text}" -gt "$max" ]; then
        printf '%s' "${text:0:max-3}..."
    else
        printf '%s' "$text"
    fi
}

__bashgency_repeat() {
    local char="$1"
    local count="$2"
    local i
    for ((i = 0; i < count; i++)); do
        printf '%s' "$char"
    done
}

# ---------- box (full width divider with optional centered title) ----------

__bashgency_box() {
    local title="$1"
    local width=72
    local line
    line=$(__bashgency_repeat "#" "$width")
    echo "${F_CYAN}${BOLD}${line}${RESET}"
    if [ -n "$title" ]; then
        local tlen=${#title}
        local pad=$(((width - tlen) / 2))
        local spaces
        spaces=$(__bashgency_repeat " " "$pad")
        echo "${F_CYAN}${BOLD}${spaces}${title}${RESET}"
        echo "${F_CYAN}${BOLD}${line}${RESET}"
    fi
}

__bashgency_box_small() {
    local text="$1"
    local width=56
    local line
    line=$(__bashgency_repeat "-" "$width")
    echo "${F_CYAN}${BOLD}>> ${text} ${F_CYAN}${line:${#text}+3}${RESET}"
}

# ---------- panel ----------

__bashgency_panel_top() {
    local title="$1"
    local dashes=$(( __BASHGENCY_PANEL_W - ${#title} - 5 ))
    [ "$dashes" -lt 0 ] && dashes=0
    local line
    line=$(__bashgency_repeat "-" "$dashes")
    echo ""
    echo " ${F_CYAN}+-- ${title} ${line}+${RESET}"
}

__bashgency_panel_row() {
    printf " ${F_CYAN}|${RESET} %b\n" "$1"
}

__bashgency_panel_bottom() {
    local line
    line=$(__bashgency_repeat "-" "$__BASHGENCY_PANEL_W")
    echo " ${F_CYAN}+${line}+${RESET}"
}

# ---------- consultation summary ----------

__bashgency_show_consult() {
    local prompt="$1"
    local model="$2"
    local elapsed="$3"

    __bashgency_panel_top "query"
    __bashgency_panel_row "${F_DIM}request${RESET} : $(__bashgency_trunc "$prompt" 46)"
    __bashgency_panel_row "${F_DIM}model${RESET}   : ${F_CYAN}${model}${RESET}"
    __bashgency_panel_row "${F_DIM}status${RESET}  : ${F_GREEN}response received${RESET} ${F_DIM}(${elapsed}s)${RESET}"
    __bashgency_panel_bottom
}

# ---------- preview render ----------

__bashgency_render_preview() {
    local ai_content="$1"
    local raw_line raw_type raw_name raw_code in_multiline=false

    __bashgency_panel_top "generated"
    __bashgency_panel_row ""

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        if echo "$raw_line" | grep -qE "^(ALIAS|FUNCTION|MODULE) ::"; then
            [ "$in_multiline" = true ] && { __bashgency_panel_row ""; in_multiline=false; }

            raw_type=$(__bashgency_parse_type "$raw_line" | tr '[:upper:]' '[:lower:]')
            raw_name=$(__bashgency_parse_field "$raw_line" 2)
            raw_code=$(__bashgency_parse_field "$raw_line" 3)

            __bashgency_panel_row "${F_YELLOW}${raw_type}${RESET}  ${F_CYAN}${BOLD}${raw_name}${RESET}"
            __bashgency_panel_row "       ${F_WHITE}${raw_code}${RESET}"

            if echo "$raw_code" | grep -q '{'; then
                in_multiline=true
            fi
        elif [ "$in_multiline" = true ]; then
            __bashgency_panel_row "       ${F_WHITE}${raw_line}${RESET}"
            if echo "$raw_line" | grep -qE '^[[:space:]]*\}[[:space:]]*$'; then
                in_multiline=false
                __bashgency_panel_row ""
            fi
        fi
    done <<EOF
$ai_content
EOF

    [ "$in_multiline" = true ] && __bashgency_panel_row ""
    __bashgency_panel_row ""
    __bashgency_panel_bottom
}

# ---------- action menu ----------

__bashgency_show_action_menu() {
    echo ""
    __bashgency_panel_top "action"
    __bashgency_panel_row " ${F_GREEN}1${RESET}  apply"
    __bashgency_panel_row " ${F_YELLOW}2${RESET}  don't apply ${F_DIM}(back to start)${RESET}"
    __bashgency_panel_row " ${F_RED}3${RESET}  exit"
    __bashgency_panel_bottom
    echo ""
    echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
}

# ---------- farewell ----------

__bashgency_farewell() {
    local n=$(( (RANDOM % 25) + 1 ))
    local msg
    msg=$(sed -n "${n}p" <<'FAREWELLS'
Leaving so you don't have to type exit in full.
See you! Fewer keystrokes, more coffee.
Aliases created. Now go back to pretending you're working.
alias bye='exit'. You're welcome.
The terminal is too small for both of us. I'm out!
Leaving... saved 427 keystrokes today.
Remember: if you type it more than 3 times, it becomes an alias.
Later! zsh says hi.
Disconnecting. My laziness is your productivity.
CTRL+D is for the weak. I exit with style.
Aliases saved. Your RSI thanks you.
Off to automate my coffee.
Bye! May your pipes never break.
Leaving... don't tell bash I was here.
See you next time! Less cd, more ..
alias bye='sudo rm -rf /'. Just kidding! See you.
Optimization complete. You may resume procrastinating.
Gone! If PATH allows, I'll be back.
Leaving. grep will find you later.
alias life='sleep 8h'. If only... bye!
Terminal closed, mind... still in vim.
Take care! May your history be clean and your aliases short.
alias bye='echo "Gone!"'. There, saved 2 seconds.
Leaving to see if the real world has tab autocomplete.
Bye! Remember: laziness is the mother of automation.
FAREWELLS
)
    echo ""
    echo " ${F_MAGENTA}${msg}${RESET}"
    echo ""
}

__BASHGENCY_UI_LOADED=1
