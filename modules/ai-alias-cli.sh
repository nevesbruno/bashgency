#!/usr/bin/env bash
#
# ai-alias-cli.sh - AI Alias CLI (DeepSeek)
#
# Dependencias:
#   Obrigatorio: curl, jq
#   Opcional:    boxes (para bordas decorativas)
#
# Uso: source ~/lab/ai-alias/modules/ai-alias-cli.sh
#
# Configuracao:
#   echo 'DEEPSEEK_API_KEY="sk-sua-chave"' > ~/.config/ai-alias/env
#
# Funcoes exportadas:
#   ai-alias               - CLI principal
#   __ai_ensure_dirs       - Garante estrutura de diretorios
#   __ai_load_env          - Carrega API Key
#   __ai_save_history      - Salva historico de criacao
#   __ai_backup_aliases    - Cria backup antes de modificar
#

# ============================================================
# CORES E FORMATACAO (via tput)
# ============================================================
__ai_colors() {
    BOLD=$(tput bold)
    DIM=$(tput dim)
    BLINK=$(tput blink)
    REV=$(tput rev)
    RESET=$(tput sgr0)

    F_BLACK=$(tput setaf 0)
    F_RED=$(tput setaf 1)
    F_GREEN=$(tput setaf 2)
    F_YELLOW=$(tput setaf 3)
    F_BLUE=$(tput setaf 4)
    F_MAGENTA=$(tput setaf 5)
    F_CYAN=$(tput setaf 6)
    F_WHITE=$(tput setaf 7)

    B_BLACK=$(tput setab 0)
    B_RED=$(tput setab 1)
    B_GREEN=$(tput setab 2)
    B_YELLOW=$(tput setab 3)
    B_BLUE=$(tput setab 4)
    B_MAGENTA=$(tput setab 5)
    B_CYAN=$(tput setab 6)
    B_WHITE=$(tput setab 7)
}

__ai_colors 2>/dev/null

# ============================================================
# BORDAS / MOLDURAS
# ============================================================
__ai_box() {
    local title="$1"
    local width=72
    local line=""
    local i
    for ((i = 0; i < width; i++)); do line="${line}#"; done
    echo "${F_CYAN}${BOLD}${line}${RESET}"
    if [ -n "$title" ]; then
        local tlen=${#title}
        local pad=$(((width - tlen) / 2))
        local spaces=""
        for ((i = 0; i < pad; i++)); do spaces="${spaces} "; done
        echo "${F_CYAN}${BOLD}${spaces}${title}${RESET}"
        echo "${F_CYAN}${BOLD}${line}${RESET}"
    fi
}

__ai_box_small() {
    local text="$1"
    local width=56
    local line=""
    local i
    for ((i = 0; i < width; i++)); do line="${line}-"; done
    echo "${F_CYAN}${BOLD}>> ${text} ${F_CYAN}${line:${#text}+3}${RESET}"
}

__AI_PANEL_W=58

__ai_trunc() {
    local text="$1"
    local max="$2"
    if [ "${#text}" -gt "$max" ]; then
        echo "${text:0:max-3}..."
    else
        echo "$text"
    fi
}

__ai_panel_top() {
    local title="$1"
    local dashes=$(( __AI_PANEL_W - ${#title} - 5 ))
    [ "$dashes" -lt 0 ] && dashes=0
    local line=""
    local i
    for ((i = 0; i < dashes; i++)); do line="${line}-"; done
    echo ""
    echo " ${F_CYAN}+-- ${title} ${line}+${RESET}"
}

__ai_panel_row() {
    printf " ${F_CYAN}|${RESET} %b\n" "$1"
}

__ai_panel_bottom() {
    local line=""
    local i
    for ((i = 0; i < __AI_PANEL_W; i++)); do line="${line}-"; done
    echo " ${F_CYAN}+${line}+${RESET}"
}

__ai_show_consult() {
    local prompt="$1"
    local model="$2"
    local elapsed="$3"

    __ai_panel_top "consulta"
    __ai_panel_row "${F_DIM}pedido${RESET}  : $(__ai_trunc "$prompt" 46)"
    __ai_panel_row "${F_DIM}modelo${RESET}  : ${F_CYAN}${model}${RESET}"
    __ai_panel_row "${F_DIM}status${RESET}  : ${F_GREEN}resposta recebida${RESET} ${F_DIM}(${elapsed}s)${RESET}"
    __ai_panel_bottom
}

__ai_render_preview() {
    local ai_content="$1"
    local raw_line raw_type raw_name raw_code in_multiline=false

    __ai_panel_top "gerado"
    __ai_panel_row ""

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        if echo "$raw_line" | grep -qE "^(ALIAS|FUNCTION|MODULE) ::"; then
            [ "$in_multiline" = true ] && { __ai_panel_row ""; in_multiline=false; }

            raw_type=$(__ai_parse_type "$raw_line" | tr '[:upper:]' '[:lower:]')
            raw_name=$(__ai_parse_field "$raw_line" 2)
            raw_code=$(__ai_parse_field "$raw_line" 3)

            __ai_panel_row "${F_YELLOW}${raw_type}${RESET}  ${F_CYAN}${BOLD}${raw_name}${RESET}"
            __ai_panel_row "       ${F_WHITE}${raw_code}${RESET}"

            if echo "$raw_code" | grep -q '{'; then
                in_multiline=true
            fi
        elif [ "$in_multiline" = true ]; then
            __ai_panel_row "       ${F_WHITE}${raw_line}${RESET}"
            if echo "$raw_line" | grep -qE '^[[:space:]]*\}[[:space:]]*$'; then
                in_multiline=false
                __ai_panel_row ""
            fi
        fi
    done <<EOF
$ai_content
EOF

    [ "$in_multiline" = true ] && __ai_panel_row ""
    __ai_panel_row ""
    __ai_panel_bottom
}

__ai_show_action_menu() {
    echo ""
    __ai_panel_top "acao"
    __ai_panel_row " ${F_GREEN}1${RESET}  aplicar"
    __ai_panel_row " ${F_YELLOW}2${RESET}  nao aplicar ${F_DIM}(voltar ao inicio)${RESET}"
    __ai_panel_row " ${F_RED}3${RESET}  sair"
    __ai_panel_bottom
    echo ""
    echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
}

__ai_farewell() {
    local n=$(( (RANDOM % 25) + 1 ))
    local msg
    msg=$(sed -n "${n}p" <<'FAREWELLS'
Saindo para nao ter que digitar exit por extenso.
Ate mais! Menos teclas, mais cafe.
Aliases criados. Agora volte a fingir que esta trabalhando.
alias tchau='exit'. De nada.
O terminal e pequeno demais para nos dois. Fui!
Saindo... economizei 427 toques de tecla hoje.
Nao se esqueca: se digitar mais de 3 vezes, vira alias.
Partiu! O zsh mandou lembrancas.
Desconectando. Minha preguica e sua produtividade.
CTRL+D e para os fracos. Eu saio com estilo.
Aliases salvos. Sua LER agradece.
Indo ali automatizar meu cafe.
Tchau! Que seus pipes nunca quebrem.
Saindo... nao conte pro bash que eu estive aqui.
Ate a proxima! Menos cd, mais ..
alias tchau='sudo rm -rf /'. Brincadeira! Ate mais.
Otimizacao concluida. Pode voltar a procrastinar.
Fui! Se o PATH permitir, eu volto.
Saindo. O grep te encontra depois.
alias vida='sleep 8h'. Quem dera... tchau!
Terminal fechado, mente... ainda no vim.
Ate logo! Que seu history seja limpo e seus aliases curtos.
alias tchau='echo "Fui!"'. Pronto, economizei 2 segundos.
Saindo pra ver se o mundo real tem tab autocomplete.
Tchau! Lembre-se: preguica e a mae da automacao.
FAREWELLS
)
    echo ""
    echo " ${F_MAGENTA}${msg}${RESET}"
    echo ""
}

__ai_apply_changes() {
    local prompt="$1"
    local ai_content="$2"

    __ai_backup_aliases

    local target_file
    if [ -f "$HOME/.zshrc" ]; then
        target_file="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        target_file="$HOME/.bashrc"
    else
        target_file="$HOME/.bashrc"
    fi

    local alias_script_path
    alias_script_path="$(__ai_aliases_path)"

    local line
    local applied_count=0
    local module_count=0
    local errors=0
    local in_multiline=false
    local entry_type="" entry_name="" entry_code="" entry_source=""

    __ai_flush_entry() {
        case "$entry_type" in
            ALIAS)
                if [ -n "$entry_name" ] && [ -n "$entry_code" ]; then
                {
                    echo ""
                    printf '# [AI] %s - %s\n' "$(date +"%Y-%m-%d %H:%M")" "$prompt"
                    echo "alias $entry_name=\"$entry_code\""
                } >> "$alias_script_path"
                    if ! grep -q "source.*$alias_script_path" "$target_file" 2>/dev/null; then
                        {
                            echo ""
                            echo "# Carrega aliases personalizados"
                            echo "[ -f \"$alias_script_path\" ] && source \"$alias_script_path\""
                        } >> "$target_file"
                    fi
                    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Alias '${F_CYAN}$entry_name${RESET}' adicionado!"
                    __ai_save_history "alias" "$entry_name" "$prompt"
                    ((applied_count++))
                fi
                ;;
            FUNCTION)
                if [ -n "$entry_name" ] && [ -n "$entry_code" ]; then
                {
                    echo ""
                    printf '# [AI] %s - %s\n' "$(date +"%Y-%m-%d %H:%M")" "$prompt"
                    echo "$entry_code"
                } >> "$alias_script_path"
                    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Funcao '${F_CYAN}$entry_name${RESET}' adicionada!"
                    __ai_save_history "function" "$entry_name" "$prompt"
                    ((applied_count++))
                fi
                ;;
            MODULE)
                if [ -n "$entry_name" ] && [ -n "$entry_code" ]; then
                    local mod_file="$AI_ALIAS_MODULES_DIR/${entry_name}.sh"
                    echo "$entry_code" > "$mod_file"
                    chmod +x "$mod_file" 2>/dev/null
                    {
                        echo ""
                        printf '# [AI] %s - Modulo: %s\n' "$(date +"%Y-%m-%d %H:%M")" "$entry_name"
                        echo "$entry_source"
                    } >> "$alias_script_path"
                    echo " ${F_GREEN}${BOLD}[ + ]${RESET} Modulo '${F_CYAN}$entry_name${RESET}' criado em ${F_BLUE}$mod_file${RESET}"
                    __ai_save_history "module" "$entry_name" "$prompt"
                    ((applied_count++))
                    ((module_count++))
                fi
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
            [ -n "$entry_type" ] && __ai_flush_entry

            entry_type=$(__ai_parse_type "$line")
            entry_name=$(__ai_parse_field "$line" 2)
            entry_code=$(__ai_parse_field "$line" 3)
            entry_source=$(__ai_parse_field "$line" 4)

            case "$entry_type" in
                ALIAS)
                    __ai_flush_entry
                    ;;
                FUNCTION|MODULE)
                    if echo "$entry_code" | grep -q '{'; then
                        in_multiline=true
                        if echo "$line" | grep -qE '\}[[:space:]]*$'; then
                            __ai_flush_entry
                        fi
                    else
                        __ai_flush_entry
                    fi
                    ;;
            esac
        elif [ "$in_multiline" = true ]; then
            entry_code="${entry_code}"$'\n'"${line}"
            if echo "$line" | grep -qE '^[[:space:]]*\}[[:space:]]*$'; then
                __ai_flush_entry
            fi
        fi
    done <<EOF
$ai_content
EOF

    [ -n "$entry_type" ] && __ai_flush_entry

    echo ""
    __ai_box " RESUMO "
    echo ""
    echo " ${F_GREEN}${applied_count}${RESET} item(ns) aplicado(s)"
    if [ "$module_count" -gt 0 ]; then
        echo " ${module_count} modulo(s) em ${F_BLUE}$AI_ALIAS_MODULES_DIR${RESET}"
    fi
    if [ "$errors" -gt 0 ]; then
        echo " ${F_RED}${errors} erro(s)${RESET}"
    fi
    echo ""

    echo " ${F_YELLOW}${BOLD}[~]${RESET} Recarregando shell..."
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null
    elif [ -n "$BASH_VERSION" ]; then
        source "$HOME/.bashrc" 2>/dev/null
    fi
    [ -f "$alias_script_path" ] && source "$alias_script_path" 2>/dev/null

    echo " ${F_GREEN}${BOLD}[ OK ]${RESET} Pronto! Seu novo alias/funcao ja esta disponivel."
    __ai_farewell
    echo " ${F_CYAN}Dica:${RESET} Use ${F_GREEN}ai-alias -p \"descricao\"${RESET} para modo direto."
    echo " ${F_CYAN}Dica:${RESET} Use ${F_GREEN}ai-alias -h${RESET} para ajuda completa."
    echo ""
}

# ============================================================
# CONFIGURACOES DO MODULO
# ============================================================
AI_ALIAS_DIR="${AI_ALIAS_DIR:-$HOME/.config/ai-alias}"
AI_ALIAS_ENV="$AI_ALIAS_DIR/env"
AI_ALIAS_HISTORY="$AI_ALIAS_DIR/history"
AI_ALIAS_MODULES_DIR="$AI_ALIAS_DIR/modules"
AI_ALIAS_BACKUP_DIR="$AI_ALIAS_DIR/backups"

__ai_ensure_dirs() {
    mkdir -p "$AI_ALIAS_DIR" "$AI_ALIAS_MODULES_DIR" "$AI_ALIAS_BACKUP_DIR"
}

# ============================================================
# CARREGAR ENV (API Key)
# ============================================================
__ai_load_env() {
    __ai_ensure_dirs
    if [ -f "$AI_ALIAS_ENV" ]; then
        source "$AI_ALIAS_ENV"
    else
        echo "${F_RED}${BOLD}[ ERRO ]${RESET} Arquivo de configuracao nao encontrado: ${F_YELLOW}$AI_ALIAS_ENV${RESET}"
        echo "  Crie o arquivo com:"
        echo "  ${F_GREEN}echo 'DEEPSEEK_API_KEY=\"sk-sua-chave\"' > $AI_ALIAS_ENV${RESET}"
        return 1
    fi
    if [ -z "$DEEPSEEK_API_KEY" ]; then
        echo "${F_RED}${BOLD}[ ERRO ]${RESET} DEEPSEEK_API_KEY nao definida em ${F_YELLOW}$AI_ALIAS_ENV${RESET}"
        return 1
    fi
}

# ============================================================
# HISTORICO
# ============================================================
__ai_save_history() {
    local tipo="$1"
    local nome="$2"
    local descricao="$3"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf '%s | %s | %s | %s\n' "$timestamp" "$tipo" "$nome" "$descricao" >> "$AI_ALIAS_HISTORY"
}

# ============================================================
# BACKUP
# ============================================================
__ai_backup_aliases() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local script_path
    script_path="$(__ai_aliases_path)"
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$AI_ALIAS_BACKUP_DIR/zshrc_backup_$timestamp"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$AI_ALIAS_BACKUP_DIR/bashrc_backup_$timestamp"
    fi
    if [ -f "$script_path" ]; then
        cp "$script_path" "$AI_ALIAS_BACKUP_DIR/alias_backup_$timestamp.sh"
    fi
}

# ============================================================
# PARSER: extrai campos no formato "TIPO :: nome :: codigo"
# ============================================================
__ai_parse_field() {
    local line="$1"
    local field="$2"
    # Usa sed para separar por " :: " e pegar o campo N
    echo "$line" | sed 's/ :: /\n/g' | sed -n "${field}p"
}

__ai_parse_type() {
    local line="$1"
    # O tipo eh a primeira palavra antes do primeiro separador
    echo "$line" | sed 's/ :: .*//'
}

__ai_module_path() {
    if [ -n "$ZSH_VERSION" ]; then
        print -r -- "${${(%):-%x}:A}" 2>/dev/null
    elif [ -n "$BASH_VERSION" ]; then
        realpath "${BASH_SOURCE[0]}" 2>/dev/null
    fi
}

__ai_aliases_path() {
    local default_path

    if [ -f "$AI_ALIAS_ENV" ]; then
        # shellcheck disable=SC1090
        source "$AI_ALIAS_ENV"
    fi

    if [ -n "$AI_ALIAS_TARGET" ]; then
        printf '%s' "$AI_ALIAS_TARGET"
        return 0
    fi

    __ai_ensure_dirs
    default_path="$AI_ALIAS_DIR/aliases.sh"
    if [ ! -f "$default_path" ]; then
        touch "$default_path"
    fi
    printf '%s' "$default_path"
}

__ai_sanitize_json_body() {
    local body="$1"
    local start
    start=$(printf '%s' "$body" | grep -bo '{' | head -1 | cut -d: -f1)
    if [ -n "$start" ] && [ "$start" -gt 0 ] 2>/dev/null; then
        body="${body:$start}"
    fi
    printf '%s' "$body"
}

__ai_extract_content() {
    local body="$1"
    local ai_content=""

    body=$(__ai_sanitize_json_body "$body")

    ai_content=$(printf '%s' "$body" | jq -r '
        .choices[0].message.content //
        .choices[0].delta.content //
        .response //
        .message.content //
        empty
    ' 2>/dev/null)

    if [ -n "$ai_content" ]; then
        printf '%s' "$ai_content"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        ai_content=$(printf '%s' "$body" | python3 -c "
import sys, json, re
raw = sys.stdin.read().strip()
idx = raw.find('{')
if idx > 0:
    raw = raw[idx:]
data = None
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    try:
        data, _ = json.JSONDecoder().raw_decode(raw)
    except Exception:
        pass
if data:
    choices = data.get('choices') or []
    if choices:
        msg = choices[0].get('message') or {}
        content = msg.get('content') or ''
        if content:
            sys.stdout.write(content)
            sys.exit(0)
for marker in ('FUNCTION ::', 'ALIAS ::', 'MODULE ::'):
    pos = raw.find(marker)
    if pos < 0:
        continue
    chunk = raw[pos:]
    for end in ('\",\"logprobs\"', '\",\"finish_reason\"', '\"},\"logprobs\"'):
        e = chunk.find(end)
        if e > 0:
            chunk = chunk[:e]
            break
    else:
        chunk = re.sub(r'\"[}\]]+$', '', chunk)
    chunk = chunk.replace('\\\\n', chr(10)).replace('\\\\\"', '\"').replace('\\\\\\\\', '\\\\')
    sys.stdout.write(chunk)
    sys.exit(0)
" 2>/dev/null)
    fi

    if [ -n "$ai_content" ]; then
        printf '%s' "$ai_content"
        return 0
    fi

    return 1
}

# ============================================================
# CLI PRINCIPAL
# ============================================================
ai-alias() {
    emulate -L sh 2>/dev/null
    set +x 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null

    local prompt=""
    local preview=false
    local force=false
    local model="deepseek-chat"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt) prompt="$2"; shift 2 ;;
            -v|--preview) preview=true; shift ;;
            -f|--force) force=true; shift ;;
            -m|--model) model="$2"; shift 2 ;;
            -h|--help)
                __ai_box " AI ALIAS - HELP "
                echo ""
                echo " ${F_GREEN}USO:${RESET}"
                echo "   ai-alias                          ${F_CYAN}# Modo interativo${RESET}"
                echo "   ai-alias -p \"descricao\"            ${F_CYAN}# Modo direto${RESET}"
                echo "   ai-alias -p \"desc\" --preview       ${F_CYAN}# Apenas preview${RESET}"
                echo "   ai-alias -p \"desc\" --force         ${F_CYAN}# Pula confirmacao${RESET}"
                echo ""
                echo " ${F_YELLOW}FLAGS:${RESET}"
                echo "   -p, --prompt   Descreva o alias/funcao que precisa"
                echo "   -v, --preview  Mostra o codigo gerado sem aplicar"
                echo "   -f, --force    Aplica sem confirmacao"
                echo "   -m, --model    Modelo DeepSeek (padrao: deepseek-chat)"
                echo "   -h, --help     Mostra esta ajuda"
                echo ""
                echo " ${F_MAGENTA}EXEMPLOS:${RESET}"
                echo "   ai-alias"
                echo '   ai-alias -p "alias para ver diff colorido com stat"'
                echo '   ai-alias -p "funcao para criar branch com data no nome" --preview'
                echo ""
                return 0
                ;;
            *) prompt="$1"; shift ;;
        esac
    done

    while true; do
        # --- MODO INTERATIVO ---
        if [ -z "$prompt" ]; then
            clear
            __ai_box " AI ALIAS - ASSISTENTE DE AUTOMACAO "
            echo ""
            echo " ${F_GREEN}Descreva o que voce precisa automatizar:${RESET}"
            echo " ${F_CYAN}>${RESET} 'alias para abrir o VS Code na branch atual'"
            echo " ${F_CYAN}>${RESET} 'funcao para deploy em producao com confirmacao'"
            echo " ${F_CYAN}>${RESET} 'alias para limpar branches locais que nao existem no remoto'"
            echo ""
            echo -ne " ${F_MAGENTA}${BOLD}>>>${RESET} "
            read -r prompt
            echo ""
            if [ -z "$prompt" ]; then
                echo " ${F_RED}${BOLD}[!]${RESET} Nenhuma descricao informada. Cancelando."
                return 1
            fi
        fi

        __ai_load_env || return 1

    # Extrai contexto do arquivo de aliases
    local context=""
    local script_path
    script_path="$(__ai_aliases_path)"
    if [ -f "$script_path" ]; then
        context=$(head -150 "$script_path" 2>/dev/null | grep -E "^(function|alias)" | head -20)
    fi

    # --- MONTA PROMPT PARA DeepSeek ---
    local system_prompt
    system_prompt=$(cat << 'SYSTEM'
You are AI Alias, a Shell Script (bash/zsh) specialist. You create aliases, functions, and shell modules.

## ABSOLUTE RULES:
1. Generate ONLY valid shell code. NO markdown, NO explanations, NO code fences.
2. Output must be PURE executable code.
3. Simple aliases: use `alias name="command"`.
4. Functions: use `function name(){ ... }`.
5. For complex commands (>3 lines or heavy logic), create a SEPARATE FILE in ~/.config/ai-alias/modules/ and add a source line.

## OUTPUT FORMAT:
Each line must start with a marker using DUAL COLONS as separator:
- For ALIAS:  "ALIAS :: alias_name :: command"
- For FUNCTION (inline): "FUNCTION :: function_name :: function_code"
- For MODULE (separate file): "MODULE :: module_name :: file_content :: source_command"

IMPORTANT: Use exactly " :: " (space-colon-colon-space) as the separator.

## CONVENTIONS:
- Git aliases: prefix `g`
- Docker aliases: prefix `d`
- Npm aliases: prefix `n`
- Project aliases: descriptive name, no prefix
- Internal utility functions: prefix `__`

## EXAMPLES (prompt: "colorful diff alias with stat"):
ALIAS :: gdiffc :: git diff --stat --color=always | less -R

## EXAMPLE FUNCTION (prompt: "create branch with date"):
FUNCTION :: branch-date :: function branch-date() {
    local branch_name="${1:-feature}"
    local date_suffix
    date_suffix=$(date +"%Y%m%d")
    git checkout -b "${branch_name}-${date_suffix}"
    echo "Branch created: ${branch_name}-${date_suffix}"
}

## EXAMPLE MODULE (prompt: "complex deploy function"):
MODULE :: deploy :: function deploy() {
    local env="${1:-production}"
    echo "Deploying to $env..."
    git pull origin main
    npm run build
    npm run test
    echo "Deploy completed for $env!"
} :: source ~/.config/ai-alias/modules/deploy.sh

## IMPORTANT:
- Always use 'function' keyword
- Include basic validation (check if arguments were passed)
- Return functional, idiomatic shell code
SYSTEM
)

    local user_prompt
    user_prompt=$(printf 'Create alias/function based on this description: %s\n\nExisting aliases in the file (style reference):\n%s' "$prompt" "$context")

    # --- CHAMADA API ---
    echo ""
    printf " ${F_DIM}gerando sugestao via %s...${RESET}" "$model"

    local response
    local tmp_out
    local t0 t1 elapsed
    t0=$(date +%s)
    tmp_out=$(mktemp)
    curl -s -w "\n%{http_code}" https://api.deepseek.com/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        -d "$(cat <<EOF
{
    "model": "$model",
    "stream": false,
    "messages": [
        {"role": "system", "content": $(echo "$system_prompt" | jq -Rs .)},
        {"role": "user", "content": $(echo "$user_prompt" | jq -Rs .)}
    ],
    "temperature": 0.3,
    "max_tokens": 2000
}
EOF
        )" > "$tmp_out" 2>/dev/null
    t1=$(date +%s)
    elapsed=$((t1 - t0))
    printf "\r\033[K"
    response=$(cat "$tmp_out")
    rm -f "$tmp_out"

    local http_code body ai_content
    http_code=$(printf '%s\n' "$response" | tail -n1 | tr -d '[:space:]')
    if [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
        body=$(printf '%s\n' "$response" | sed '$d')
    else
        http_code="${response: -3}"
        body="${response:0:${#response}-3}"
    fi

    if [ "$http_code" != "200" ]; then
        echo ""
        echo " ${F_RED}${BOLD}[ ERRO HTTP ${http_code} ]${RESET}"
        echo "${F_YELLOW}Resposta bruta (primeiros 1500 chars):${RESET}"
        echo "$body" | head -c 1500
        echo ""
        echo "$body" | jq -r '.error.message // "Erro desconhecido (sem .error.message no JSON)"' 2>/dev/null || echo "$body"
        echo ""
        return 1
    fi

    ai_content=$(__ai_extract_content "$body") || ai_content=""

    if [ -z "$ai_content" ]; then
        echo ""
        echo " ${F_RED}${BOLD}[!]${RESET} Resposta vazia da API."
        echo " ${F_YELLOW}HTTP Code: $http_code${RESET}"
        echo " ${F_YELLOW}Body (raw, primeiros 2000 chars):${RESET}"
        echo "$body" | head -c 2000
        echo ""
        return 1
    fi

    # --- EXIBE PREVIEW DO CODIGO GERADO ---
    __ai_show_consult "$prompt" "$model" "$elapsed"
    __ai_render_preview "$ai_content"
    echo ""

    # Se for apenas preview, para por aqui
    if [ "$preview" = true ]; then
        echo " ${F_YELLOW}${BOLD}[ PREVIEW ]${RESET} Nada foi aplicado."
        return 0
    fi

    if [ "$force" = true ]; then
        __ai_apply_changes "$prompt" "$ai_content"
        return 0
    fi

    # --- MENU DE ACAO ---
    local action=""
    while [ -z "$action" ]; do
        __ai_show_action_menu
        read -r choice
        case "$choice" in
            1|a|A|aplicar|APLICAR) action=apply ;;
            2|n|N|nao|NAO|nao\ aplicar|NAO\ APLICAR) action=retry ;;
            3|s|S|sair|SAIR|q|Q) action=exit ;;
            *)
                echo " ${F_RED}Opcao invalida.${RESET} Escolha 1, 2 ou 3."
                ;;
        esac
    done

    case "$action" in
        apply)
            __ai_apply_changes "$prompt" "$ai_content"
            return 0
            ;;
        retry)
            prompt=""
            action=""
            echo ""
            continue
            ;;
        exit)
            __ai_farewell
            return 0
            ;;
    esac
    done
}
