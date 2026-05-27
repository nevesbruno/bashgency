# CLI Reference - Bashgency

## Syntax

```
bashgency [OPTIONS] [freeform_prompt]
```

## Options

| Flag | Long | Description | Default |
| ---- | ---- | ----------- | ------- |
| `-p` | `--prompt` | Alias/function description | (interactive) |
| `-r` | `--run` | Execute command from natural language | (interactive) |
| `-v` | `--preview` | Show code without applying | `false` |
| `-f` | `--force` | Apply without confirmation | `false` |
| `-y` | `--yes` | Auto-confirm command execution | `false` |
| `-m` | `--model` | DeepSeek model | `deepseek-chat` |
| `-h` | `--help` | Help | - |

## Post-generation menu (alias mode)

| Input | Action |
| ----- | ------ |
| `1`, `a`, `apply` | Write and reload shell |
| `2`, `n`, `don't apply` | Retry (interactive) |
| `3`, `s`, `exit`, `q` | Quit |

## Run mode flow

```
bashgency -r "list all text files containing lorem ipsum"
  |
  v
generating command via deepseek-chat...
  |
  v
+-- query ---+
  request : list all text files...
  model   : deepseek-chat
  status  : response received (2s)
+------------+

+-- command -----------------------------+
  $ grep -rl "lorem ipsum" --include="*.txt" .
+------------------------------------------+

>>> Execute? [Y/n]
  |
  v
(output goes directly to terminal)
```

With `-y`:

```bash
bashgency -r "find largest files" -y
```

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

### Command (run mode)

Raw shell command, no marker. Single line or chained with `&&`/`;`.

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

### Alias/function mode

```bash
bashgency -p "alias gco for git checkout"
bashgency -p "alias dps for docker ps" --preview
bashgency -p "alias ll for ls -lha" --force
```

### Run mode

```bash
bashgency -r "list all text files containing lorem ipsum"
bashgency -r "find 5 largest files sorted by size" -y
bashgency -r "show all listening ports with process names"
```
