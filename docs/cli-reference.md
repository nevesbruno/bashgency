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
| `-P` | `--provider` | AI provider override | `BASHGENCY_PROVIDER` in env |
| `-m` | `--model` | Model override | per provider (see table) |
| | `--configure` | Interactive provider + API key setup | - |
| `-h` | `--help` | Help | - |

## Environment

| Variable | Description |
| -------- | ----------- |
| `BASHGENCY_NONINTERACTIVE` | If set, suppresses reconfigure prompts on 401/403 |
| `BASHGENCY_DIR` | Config directory (default `~/.config/bashgency`) |

## Providers (Tier 1)

| ID | Key env | Default model |
| -- | ------- | ------------- |
| `deepseek` | `DEEPSEEK_API_KEY` | `deepseek-chat` |
| `openai` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| `anthropic` | `ANTHROPIC_API_KEY` | `claude-3-5-haiku-latest` |
| `gemini` | `GEMINI_API_KEY` | `gemini-2.0-flash` |

More providers: [`adding-a-provider.md`](adding-a-provider.md).

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
generating command via deepseek/deepseek-chat...
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
|-- modules/lib/providers/    # connector registry

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
| `BASHGENCY_PROVIDER` | `env` | Active provider: deepseek, openai, anthropic, gemini |
| `DEEPSEEK_API_KEY` | `env` | DeepSeek authentication |
| `OPENAI_API_KEY` | `env` | OpenAI authentication |
| `ANTHROPIC_API_KEY` | `env` | Anthropic authentication |
| `GEMINI_API_KEY` | `env` | Google Gemini authentication |
| `BASHGENCY_DIR` | export | Config root override |
| `BASHGENCY_TARGET` | `env` | Aliases file override |

## Files touched on apply

| File | Condition |
| ---- | --------- |
| `~/.config/bashgency/aliases.sh` or `BASHGENCY_TARGET` | Aliases/functions |
| `~/.config/bashgency/modules/<name>.sh` | MODULE type |
| `~/.zshrc` / `~/.bashrc` | If aliases file not referenced |
| `history`, `backups/*` | Always |

## Examples

### Alias/function mode

```bash
bashgency -p "alias gco for git checkout"
bashgency -P openai -p "alias ll for ls -la" --preview
```

### Run mode

```bash
bashgency -r "show disk usage sorted by size"
bashgency -P gemini -r "list docker containers" -y
```

### Test API connectivity

```bash
bash ~/lab/bashgency/scripts/test_api.sh
bash ~/lab/bashgency/scripts/test_api.sh anthropic
```
