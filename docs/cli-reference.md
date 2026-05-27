# CLI Reference - Bashgency

## Syntax

```
bashgency [OPTIONS] [freeform_prompt]
```

## Options

| Flag | Long | Description | Default |
| ---- | ---- | ----------- | ------- |
| `-p` | `--prompt` | Alias/function description | (interactive) |
| `-v` | `--preview` | Show code without applying | `false` |
| `-f` | `--force` | Apply without confirmation | `false` |
| `-m` | `--model` | DeepSeek model | `deepseek-chat` |
| `-h` | `--help` | Help | - |

## Post-generation menu

| Input | Action |
| ----- | ------ |
| `1`, `a`, `apply` | Write and reload shell |
| `2`, `n`, `don't apply` | Retry (interactive) |
| `3`, `s`, `exit`, `q` | Quit |

## AI output format

### Alias

```
ALIAS :: <name> :: <command>
```

### Function

```
FUNCTION :: <name> :: function <name>() { ... }
```

### Module

```
MODULE :: <name> :: <content> :: source ~/.config/bashgency/modules/<name>.sh
```

## Directory structure

```
~/lab/bashgency/              # repository
|-- modules/bashgency-cli.sh

~/.config/bashgency/        # runtime
|-- env
|-- aliases.sh             # default destination
|-- history
|-- backups/
+-- modules/               # generated modules
```

## Variables

| Name | Where | Description |
| ---- | ----- | ----------- |
| `DEEPSEEK_API_KEY` | `~/.config/bashgency/env` | Required |
| `BASHGENCY_DIR` | export | Config root override |
| `BASHGENCY_TARGET` | `env` | Aliases file override |

## Files touched on apply

| File | Condition |
| ---- | --------- |
| `~/.config/bashgency/aliases.sh` or `BASHGENCY_TARGET` | Aliases/functions |
| `~/.config/bashgency/modules/<name>.sh` | MODULE type |
| `~/.zshrc` / `~/.bashrc` | If aliases file not referenced |
| `history`, `backups/*` | Always |

## DeepSeek API

| Field | Value |
| ----- | ----- |
| URL | `https://api.deepseek.com/chat/completions` |
| Auth | `Bearer $DEEPSEEK_API_KEY` |
| Model | `deepseek-chat` |
| Temperature | `0.3` |
| Max tokens | `2000` |

## Examples

```bash
bashgency -p "alias gco for git checkout"
bashgency -p "alias dps for docker ps" --preview
bashgency -p "alias ll for ls -lha" --force
```
