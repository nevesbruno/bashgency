# Bashgency

CLI that generates shell aliases, functions, and modules via AI (DeepSeek API).

## What it is

**Bashgency** turns natural-language descriptions into shell aliases, functions, or modules. It calls the DeepSeek API, shows a preview, and writes changes after your confirmation.

```
User describes need
        |
        v
   bashgency (CLI)
        |
        v
  DeepSeek API  -->  structured shell code
        |
        v
  preview + confirmation
        |
        v
  ~/.config/bashgency/aliases.sh (+ modules in modules/)
```

## Prerequisites

| Tool | Required | Install (Debian/Ubuntu) |
| ---- | -------- | ----------------------- |
| `curl` | Yes | `sudo apt install curl` |
| `jq` | Yes | `sudo apt install jq` |
| `python3` | Recommended | JSON parse fallback |
| zsh or bash | Yes | included in WSL/Linux |

## Installation

### 1. Clone the repository

```bash
git clone git@github.com:nevesbruno/bashgency.git ~/lab/bashgency
```

### 2. Configure runtime

```bash
bash ~/lab/bashgency/install.sh
# Edit ~/.config/bashgency/env and set DEEPSEEK_API_KEY
```

The installer will prompt you to add the `source` lines to your shell config (`.zshrc`, `.bashrc`, etc.) automatically.

### 3. Load in your shell

If you skipped the installer prompt, add this to `~/.zshrc` or your `alias.sh` (e.g. [bash-stuffs](https://github.com/nevesbruno/bash-stuffs)):

```bash
[ -f "$HOME/lab/bashgency/modules/bashgency-cli.sh" ] && \
  source "$HOME/lab/bashgency/modules/bashgency-cli.sh"
```

Generated aliases go to `~/.config/bashgency/aliases.sh` by default. Load them in your shell:

```bash
[ -f "$HOME/.config/bashgency/aliases.sh" ] && \
  source "$HOME/.config/bashgency/aliases.sh"
```

**Override:** to write to another file (e.g. dotfiles), in `~/.config/bashgency/env`:

```bash
BASHGENCY_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```

**Security:** never commit your API key. The `env` file stays outside git.

## Usage modes

### Interactive (default)

```bash
bashgency
```

### Direct mode

```bash
bashgency -p "alias to show a colorful diff with stat"
```

### Preview (no apply)

```bash
bashgency -p "function to create a branch with date in the name" --preview
bashgency -p "description" -v
```

### Force (skip confirmation)

```bash
bashgency -p "alias gst for git status" --force
bashgency -p "description" -f
```

### Help

```bash
bashgency -h
```

## Flow after code generation

1. **Query** -- request, model, and response time
2. **Preview** -- formatted alias/function/module
3. **Menu** -- `1` apply | `2` retry | `3` exit

## Where code is saved

| Generated type | Default destination |
| -------------- | ------------------- |
| Alias / inline function | `~/.config/bashgency/aliases.sh` |
| Complex module | `~/.config/bashgency/modules/<name>.sh` + `source` in aliases file |

With `BASHGENCY_TARGET` set, aliases and functions go to that file.

## Directory layout

| Path | Role |
| ---- | ---- |
| `~/lab/bashgency/modules/bashgency-cli.sh` | Versioned source |
| `~/.config/bashgency/env` | API key |
| `~/.config/bashgency/aliases.sh` | Generated aliases (default) |
| `~/.config/bashgency/history` | Creation log |
| `~/.config/bashgency/backups/` | Automatic backups |
| `~/.config/bashgency/modules/*.sh` | AI-generated modules |

## Troubleshooting

### Module not found

Clone to `~/lab/bashgency` and add the `source` line to your shell.

### Missing API key

```bash
bash ~/lab/bashgency/install.sh
# Edit ~/.config/bashgency/env
```

### HTTP 401/403 error

```bash
bash ~/lab/bashgency/scripts/test_api.sh
```

### Alias not available after apply

```bash
source ~/.zshrc
source ~/.config/bashgency/aliases.sh
```

### Revert

```bash
ls ~/.config/bashgency/backups/
cp ~/.config/bashgency/backups/alias_backup_YYYYMMDD_HHMMSS.sh \
   ~/.config/bashgency/aliases.sh
source ~/.config/bashgency/aliases.sh
```

## Contributing

MIT. Issues and PRs welcome. Architecture: [docs/developer-guide.md](./docs/developer-guide.md). Flags: [docs/cli-reference.md](./docs/cli-reference.md).

## Note for AI agents

Read [docs/developer-guide.md](./docs/developer-guide.md) before changing code. Minimal diffs, `__bashgency_*` conventions, and `TYPE ::` format. Never commit secrets.

## Version

See `VERSION`. Current: **1.2.1**.
