# AGENTS.md - ai-alias

## Stack

- Shell: bash/zsh
- HTTP: curl + jq (+ python3 fallback para JSON)
- API: DeepSeek (`https://api.deepseek.com/chat/completions`)

## Layout

| Path | Papel |
| ---- | ----- |
| `modules/ai-alias-cli.sh` | Codigo versionado (source de `~/lab/ai-alias`) |
| `~/.config/ai-alias/env` | Segredos (nunca commitar) |
| `~/.config/ai-alias/aliases.sh` | Destino padrao de aliases gerados |
| `~/.config/ai-alias/modules/` | Modulos shell gerados pela IA |
| `~/.config/ai-alias/history` | Log append-only |
| `~/.config/ai-alias/backups/` | Backups pre-escrita |

## Instalacao

```bash
git clone <repo> ~/lab/ai-alias
bash ~/lab/ai-alias/install.sh
# Editar ~/.config/ai-alias/env com DEEPSEEK_API_KEY
```

Integracao tipica via [bash-stuffs](https://github.com/nevesbruno/bash-stuffs) `alias.sh`:

```bash
source "$HOME/lab/ai-alias/modules/ai-alias-cli.sh"
```

## Convencoes de codigo

- Funcoes internas: prefixo `__ai_`
- Saida da IA: `ALIAS ::`, `FUNCTION ::`, `MODULE ::` com separador ` :: `
- Diffs minimos; nunca commitar `env` ou chaves API
- Bump `VERSION` + `CHANGELOG.md` em releases

## Testes rapidos

```bash
source ~/lab/ai-alias/modules/ai-alias-cli.sh
ai-alias -p "alias x para echo ok" --preview
bash ~/lab/ai-alias/scripts/test_api.sh
```

## Override de destino

Em `~/.config/ai-alias/env`:

```bash
AI_ALIAS_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```
