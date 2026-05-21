# AI Alias

CLI que gera aliases, funcoes e modulos shell via IA (DeepSeek API).

## O que e

O **AI Alias** transforma descricoes em linguagem natural em aliases, funcoes ou modulos shell. Consulta a API DeepSeek, mostra preview e grava com sua confirmacao.

```
Usuario descreve necessidade
        |
        v
   ai-alias (CLI)
        |
        v
  DeepSeek API  -->  codigo shell estruturado
        |
        v
  preview + confirmacao
        |
        v
  ~/.config/ai-alias/aliases.sh (+ modulos em modules/)
```

## Pre-requisitos

| Ferramenta | Obrigatorio | Instalacao (Debian/Ubuntu) |
| ---------- | ----------- | -------------------------- |
| `curl` | Sim | `sudo apt install curl` |
| `jq` | Sim | `sudo apt install jq` |
| `python3` | Recomendado | fallback de parse JSON |
| Shell zsh ou bash | Sim | ja incluso no WSL/Linux |

## Instalacao

### 1. Clonar o repositorio

```bash
git clone git@github.com:nevesbruno/ai-alias.git ~/lab/ai-alias
```

### 2. Configurar runtime

```bash
bash ~/lab/ai-alias/install.sh
# Edite ~/.config/ai-alias/env e defina DEEPSEEK_API_KEY
```

### 3. Carregar no shell

No `~/.zshrc` ou no seu `alias.sh` (ex. [bash-stuffs](https://github.com/nevesbruno/bash-stuffs)):

```bash
[ -f "$HOME/lab/ai-alias/modules/ai-alias-cli.sh" ] && \
  source "$HOME/lab/ai-alias/modules/ai-alias-cli.sh"
```

Aliases gerados vao para `~/.config/ai-alias/aliases.sh` por padrao. Carregue no shell:

```bash
[ -f "$HOME/.config/ai-alias/aliases.sh" ] && \
  source "$HOME/.config/ai-alias/aliases.sh"
```

**Override:** para gravar em outro arquivo (ex. dotfiles), em `~/.config/ai-alias/env`:

```bash
AI_ALIAS_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```

**Seguranca:** nunca commite a chave. O arquivo `env` fica fora do git.

## Modos de uso

### Interativo (padrao)

```bash
ai-alias
```

### Modo direto

```bash
ai-alias -p "alias para ver diff colorido com stat"
```

### Preview (nao aplica)

```bash
ai-alias -p "funcao para criar branch com data no nome" --preview
ai-alias -p "descricao" -v
```

### Force (pula confirmacao)

```bash
ai-alias -p "alias gst para git status" --force
ai-alias -p "descricao" -f
```

### Ajuda

```bash
ai-alias -h
```

## Fluxo apos gerar codigo

1. **Consulta** -- pedido, modelo e tempo de resposta
2. **Preview** -- alias/funcao/modulo formatado
3. **Menu** -- `1` aplicar | `2` retry | `3` sair

## Onde o codigo e salvo

| Tipo gerado | Destino (padrao) |
| ----------- | ---------------- |
| Alias / funcao inline | `~/.config/ai-alias/aliases.sh` |
| Modulo complexo | `~/.config/ai-alias/modules/<nome>.sh` + `source` no arquivo de aliases |

Com `AI_ALIAS_TARGET` definido, aliases e funcoes vao para esse arquivo.

## Onde fica cada coisa

| Path | Papel |
| ---- | ----- |
| `~/lab/ai-alias/modules/ai-alias-cli.sh` | Codigo versionado |
| `~/.config/ai-alias/env` | API key |
| `~/.config/ai-alias/aliases.sh` | Aliases gerados (padrao) |
| `~/.config/ai-alias/history` | Log de criacoes |
| `~/.config/ai-alias/backups/` | Backups automaticos |
| `~/.config/ai-alias/modules/*.sh` | Modulos gerados pela IA |

## Troubleshooting

### Modulo nao encontrado

Clone em `~/lab/ai-alias` e adicione o `source` no shell.

### API key ausente

```bash
bash ~/lab/ai-alias/install.sh
# Edite ~/.config/ai-alias/env
```

### Erro HTTP 401/403

```bash
bash ~/lab/ai-alias/scripts/test_api.sh
```

### Alias nao disponivel apos aplicar

```bash
source ~/.zshrc
source ~/.config/ai-alias/aliases.sh
```

### Reverter

```bash
ls ~/.config/ai-alias/backups/
cp ~/.config/ai-alias/backups/alias_backup_YYYYMMDD_HHMMSS.sh \
   ~/.config/ai-alias/aliases.sh
source ~/.config/ai-alias/aliases.sh
```

## Contribuicao

MIT. Issues e PRs bem-vindos. Arquitetura: [docs/guia-desenvolvedor.md](./docs/guia-desenvolvedor.md). Flags: [docs/referencia-cli.md](./docs/referencia-cli.md).

## Nota para agentes de IA

Leia [docs/guia-desenvolvedor.md](./docs/guia-desenvolvedor.md) antes de alterar codigo. Diffs minimos, convencoes `__ai_*` e formato `TIPO ::`. Nunca commite segredos.

## Versao

Consulte `VERSION`. Atual: **1.2.1**.
