#!/usr/bin/env bash
#
# run.sh - Semantic terminal command execution
# Part of Bashgency
#
# Generates, previews, and executes shell commands from natural
# language descriptions. Maintains audit log via history.
#

if [ -n "${__BASHGENCY_RUN_LOADED:-}" ]; then
    return 0
fi

# ---------- system prompt ----------

__bashgency_build_run_system_prompt() {
    cat << 'SYSTEM'
You are Bashgency, a Shell Script specialist. Generate ONE shell command from natural language.

## RULES
1. Output ONLY the raw command. NO markdown, NO explanations, NO code fences, NO backticks.
2. Nothing before or after the command.
3. Multi-step tasks: chain with && or ; (max 3 lines).
4. Prefer read-only unless user explicitly asks otherwise.
5. Use idiomatic, concise shell (bash/zsh).

## EXAMPLES
prompt: "list all text files containing 'lorem ipsum'"
output: grep -rl "lorem ipsum" --include="*.txt" .

prompt: "find the 5 largest files"
output: find . -type f -exec ls -s {} \; | sort -n -r | head -5

prompt: "show disk usage sorted by size"
output: du -sh * | sort -rh

prompt: "kill process on port 3000"
output: lsof -ti:3000 | xargs kill -9

prompt: "count lines of code in src"
output: find src -type f | xargs wc -l | tail -1

prompt: "list git branches merged into main"
output: git branch --merged main | grep -v "main\|develop" | sort

prompt: "show all listening ports with process names"
output: ss -tlnp | tail -n +2

prompt: "find the most recent log file and show last 50 lines"
output: tail -50 "$(ls -t *.log 2>/dev/null | head -1)"
SYSTEM
}

# ---------- helpers ----------

__bashgency_clean_run_output() {
    local content="$1"
    # Strip markdown fences, trim whitespace, drop empty lines
    printf '%s' "$content" \
        | sed 's/^```[a-z]*$//; s/^```$//' \
        | sed '/^[[:space:]]*$/d'
}

# ---------- API ----------

__bashgency_call_run_api() {
    local prompt="$1"
    local model="${2:-deepseek-chat}"

    local system_prompt
    system_prompt=$(__bashgency_build_run_system_prompt)

    __bashgency_call_api_raw "$system_prompt" "$prompt" "$model"
}

# ---------- UI ----------

__bashgency_show_run_preview() {
    local command="$1"

    __bashgency_panel_top "command"
    __bashgency_panel_row ""
    __bashgency_panel_row " ${F_WHITE}\$ ${command}${RESET}"
    __bashgency_panel_row ""
    __bashgency_panel_bottom
}

# ---------- execution ----------

__bashgency_run_command() {
    local command="$1"
    local description="$2"

    __bashgency_save_history "COMMAND" "$command" "$description"

    # Execute the command directly - output goes straight to terminal
    echo ""
    eval "$command"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo ""
        echo " ${F_RED}${BOLD}[!]${RESET} Command exited with code ${exit_code}" >&2
    fi

    return $exit_code
}

# ---------- main run flow ----------

__bashgency_run_flow() {
    local prompt="$1"
    local model="$2"
    local force="$3"

    # Interactive prompt if not provided
    if [ -z "$prompt" ]; then
        echo " ${F_GREEN}Describe what command you need:${RESET}"
        echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
        read -r prompt
        echo ""
        if [ -z "$prompt" ]; then
            echo " ${F_RED}${BOLD}[!]${RESET} No description provided."
            return 1
        fi
    fi

    # Loading
    printf " ${F_DIM}generating command via %s...${RESET}" "$model"
    local t0 t1 elapsed
    t0=$(date +%s)

    local response http_code body ai_content command
    response=$(__bashgency_call_run_api "$prompt" "$model")
    t1=$(date +%s)
    elapsed=$((t1 - t0))

    printf "\r\033[K"

    # Parse HTTP
    http_code=$(printf '%s' "$response" | tail -n1 | tr -d '[:space:]')
    if [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
        body=$(printf '%s' "$response" | sed '$d')
    else
        http_code="${response: -3}"
        body="${response:0:${#response}-3}"
    fi

    if [ "$http_code" != "200" ]; then
        echo ""
        echo " ${F_RED}${BOLD}[ HTTP ERROR ${http_code} ]${RESET}"
        echo "$body" | head -c 1500
        return 1
    fi

    ai_content=$(__bashgency_extract_content "$body")
    if [ -z "$ai_content" ]; then
        echo ""
        echo " ${F_RED}${BOLD}[!]${RESET} Empty API response."
        return 1
    fi

    command=$(__bashgency_clean_run_output "$ai_content")

    # Show summary + preview
    __bashgency_show_consult "$prompt" "$model" "$elapsed"
    __bashgency_show_run_preview "$command"

    # Auto-approve
    if [ "$force" = true ]; then
        __bashgency_run_command "$command" "$prompt"
        return $?
    fi

    # Approval prompt
    echo ""
    echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} Execute? ${F_GREEN}[Y/n]${RESET} "
    read -r approval
    case "$approval" in
        n|N|no|NO|nao|NAO)
            echo " ${F_YELLOW}Cancelled.${RESET}"
            return 1
            ;;
    esac

    __bashgency_run_command "$command" "$prompt"
}

__BASHGENCY_RUN_LOADED=1
