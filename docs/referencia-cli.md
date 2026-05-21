# Referencia CLI - AI Alias

## Sintaxe

```
ai-alias [OPCOES] [prompt_livre]
```

## Opcoes

| Flag | Longa | Descricao | Default |
| ---- | ----- | --------- | ------- |
| `-p` | `--prompt` | Descricao do alias/funcao | (interativo) |
| `-v` | `--preview` | Mostra codigo sem aplicar | `false` |
| `-f` | `--force` | Aplica sem confirmacao | `false` |
| `-m` | `--model` | Modelo DeepSeek | `deepseek-chat` |
| `-h` | `--help` | Ajuda | - |

## Menu pos-geracao

| Entrada | Acao |
| ------- | ---- |
| `1`, `a`, `aplicar` | Grava e recarrega shell |
| `2`, `n`, `nao aplicar` | Retry (interativo) |
| `3`, `s`, `sair`, `q` | Encerra |

## Formato de saida da IA

### Alias

```
ALIAS :: <nome> :: <comando>
```

### Funcao

```
FUNCTION :: <nome> :: function <nome>() { ... }
```

### Modulo

```
MODULE :: <nome> :: <conteudo> :: source ~/.config/ai-alias/modules/<nome>.sh
```

## Estrutura de diretorios

```
~/lab/ai-alias/              # repositorio
|-- modules/ai-alias-cli.sh

~/.config/ai-alias/        # runtime
|-- env
|-- aliases.sh             # destino padrao
|-- history
|-- backups/
+-- modules/               # modulos gerados
```

## Variaveis

| Nome | Onde | Descricao |
| ---- | ---- | --------- |
| `DEEPSEEK_API_KEY` | `~/.config/ai-alias/env` | Obrigatoria |
| `AI_ALIAS_DIR` | export | Override raiz config |
| `AI_ALIAS_TARGET` | `env` | Override arquivo de aliases |

## Arquivos tocados ao aplicar

| Arquivo | Condicao |
| ------- | -------- |
| `~/.config/ai-alias/aliases.sh` ou `AI_ALIAS_TARGET` | Aliases/funcoes |
| `~/.config/ai-alias/modules/<nome>.sh` | Tipo MODULE |
| `~/.zshrc` / `~/.bashrc` | Se arquivo de aliases nao referenciado |
| `history`, `backups/*` | Sempre |

## API DeepSeek

| Campo | Valor |
| ----- | ----- |
| URL | `https://api.deepseek.com/chat/completions` |
| Auth | `Bearer $DEEPSEEK_API_KEY` |
| Modelo | `deepseek-chat` |
| Temperature | `0.3` |
| Max tokens | `2000` |

## Exemplos

```bash
ai-alias -p "alias gco para git checkout"
ai-alias -p "alias dps para docker ps" --preview
ai-alias -p "alias ll para ls -lha" --force
```
