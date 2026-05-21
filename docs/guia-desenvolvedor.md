# Guia do Desenvolvedor - AI Alias

## Arquitetura

```
~/lab/ai-alias/modules/ai-alias-cli.sh  (repo)
        |
        +-- ai-alias()           # CLI principal
        +-- __ai_*()             # funcoes internas
        +-- __ai_apply_changes() # parser + escrita
        +-- __ai_extract_content() # parse resposta API

bash-stuffs/alias.sh (opcional)
        |
        +-- source ~/lab/ai-alias/modules/ai-alias-cli.sh
```

### Separacao repo vs runtime

| Local | Proposito |
| ----- | --------- |
| `~/lab/ai-alias/modules/ai-alias-cli.sh` | Fonte versionada |
| `~/.config/ai-alias/env` | Segredos (fora do git) |
| `~/.config/ai-alias/aliases.sh` | Destino padrao de aliases gerados |
| `~/.config/ai-alias/modules/` | Modulos gerados pela IA |

Loader tipico no bash-stuffs:

```bash
_AI_ALIAS_MODULE="$HOME/lab/ai-alias/modules/ai-alias-cli.sh"
[ -f "$_AI_ALIAS_MODULE" ] && source "$_AI_ALIAS_MODULE"
```

Nao e necessario copiar o modulo para `~/.config`; edite direto no repo e `source` de novo.

## Funcoes exportadas e internas

### Publicas

| Funcao | Descricao |
| ------ | --------- |
| `ai-alias` | Entry point da CLI |

### Internas (`__ai_*`)

| Funcao | Responsabilidade |
| ------ | ---------------- |
| `__ai_colors` | Cores via `tput` |
| `__ai_panel_*` | Painel de preview |
| `__ai_apply_changes` | Parser + escrita em disco |
| `__ai_aliases_path` | Resolve arquivo de aliases |
| `__ai_extract_content` | Parse resposta API |

## Formato de saida da IA

```
ALIAS :: nome :: comando
FUNCTION :: nome :: function nome(){ ... }
MODULE :: nome :: conteudo_arquivo :: source ~/.config/ai-alias/modules/nome.sh
```

Separador: ` :: `

## Integracao com API

**Endpoint:** `https://api.deepseek.com/chat/completions`

**Contexto:** primeiras 150 linhas do arquivo de aliases, filtro `^(function|alias)`, max 20 entradas.

## Variaveis

| Variavel | Default | Uso |
| -------- | ------- | --- |
| `AI_ALIAS_DIR` | `$HOME/.config/ai-alias` | Raiz de config |
| `AI_ALIAS_TARGET` | (vazio) | Override do arquivo de aliases |
| `DEEPSEEK_API_KEY` | em `env` | Autenticacao API |

### `__ai_aliases_path` (prioridade)

1. `AI_ALIAS_TARGET` (de `env` ou ambiente)
2. `$AI_ALIAS_DIR/aliases.sh` (cria se ausente)

## Como estender

### Mudar destino dos aliases

Em `~/.config/ai-alias/env`:

```bash
AI_ALIAS_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```

### Trocar provider de IA

Alterar `__ai_load_env`, curl em `ai-alias()`, e `__ai_extract_content`.

## Desenvolvimento local

```bash
bash ~/lab/ai-alias/scripts/test_api.sh
source ~/lab/ai-alias/modules/ai-alias-cli.sh
ai-alias -p "alias teste para echo ok" --preview
```

Sandbox:

```bash
export AI_ALIAS_DIR="/tmp/ai-alias-test"
mkdir -p "$AI_ALIAS_DIR/modules" "$AI_ALIAS_DIR/backups"
```

## Checklist para PR

- [ ] Alteracao em `modules/ai-alias-cli.sh`
- [ ] `ai-alias -p "..." --preview` ok
- [ ] Sem segredos no commit
- [ ] Docs em `docs/` se comportamento mudou
- [ ] Bump `VERSION` + `CHANGELOG.md` se release

## Limitacoes conhecidas

| Limitacao | Detalhe |
| --------- | ------- |
| Sem deduplicacao | Reaplicar cria entrada duplicada |
| Sem undo automatico | Usar backups em `backups/` |
| Contexto limitado | 20 aliases de referencia na IA |
