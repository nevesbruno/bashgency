# Developer Guide - Bashgency

## Architecture

```
~/lab/bashgency/modules/bashgency-cli.sh  (repo)
        |
        +-- bashgency()           # main CLI
        +-- __bashgency_*()       # internal functions
        +-- __bashgency_apply_changes() # parser + write
        +-- __bashgency_extract_content() # API response parse

bash-stuffs/alias.sh (optional)
        |
        +-- source ~/lab/bashgency/modules/bashgency-cli.sh
```

### Repo vs runtime separation

| Location | Purpose |
| -------- | ------- |
| `~/lab/bashgency/modules/bashgency-cli.sh` | Versioned source |
| `~/.config/bashgency/env` | Secrets (outside git) |
| `~/.config/bashgency/aliases.sh` | Default destination for generated aliases |
| `~/.config/bashgency/modules/` | AI-generated modules |

Typical loader in bash-stuffs:

```bash
_BASHGENCY_MODULE="$HOME/lab/bashgency/modules/bashgency-cli.sh"
[ -f "$_BASHGENCY_MODULE" ] && source "$_BASHGENCY_MODULE"
```

No need to copy the module to `~/.config`; edit directly in the repo and re-`source`.

## Exported and internal functions

### Public

| Function | Description |
| -------- | ----------- |
| `bashgency` | CLI entry point |

### Internal (`__bashgency_*`)

| Function | Responsibility |
| -------- | -------------- |
| `__bashgency_colors` | Colors via `tput` |
| `__bashgency_panel_*` | Preview panel |
| `__bashgency_apply_changes` | Parser + disk write |
| `__bashgency_aliases_path` | Resolve aliases file |
| `__bashgency_extract_content` | Parse API response |

## AI output format

```
ALIAS :: name :: command
FUNCTION :: name :: function name(){ ... }
MODULE :: name :: file_content :: source ~/.config/bashgency/modules/name.sh
```

Separator: ` :: `

## API integration

**Endpoint:** `https://api.deepseek.com/chat/completions`

**Context:** first 150 lines of the aliases file, filter `^(function|alias)`, max 20 entries.

## Variables

| Variable | Default | Usage |
| -------- | ------- | ----- |
| `BASHGENCY_DIR` | `$HOME/.config/bashgency` | Config root |
| `BASHGENCY_TARGET` | (empty) | Aliases file override |
| `DEEPSEEK_API_KEY` | in `env` | API authentication |

### `__bashgency_aliases_path` (priority)

1. `BASHGENCY_TARGET` (from `env` or environment)
2. `$BASHGENCY_DIR/aliases.sh` (creates if missing)

## How to extend

### Change aliases destination

In `~/.config/bashgency/env`:

```bash
BASHGENCY_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```

### Switch AI provider

Change `__bashgency_load_env`, curl in `bashgency()`, and `__bashgency_extract_content`.

## Local development

```bash
bash ~/lab/bashgency/scripts/test_api.sh
source ~/lab/bashgency/modules/bashgency-cli.sh
bashgency -p "alias test for echo ok" --preview
```

Sandbox:

```bash
export BASHGENCY_DIR="/tmp/bashgency-test"
mkdir -p "$BASHGENCY_DIR/modules" "$BASHGENCY_DIR/backups"
```

## PR checklist

- [ ] Change in `modules/bashgency-cli.sh`
- [ ] `bashgency -p "..." --preview` works
- [ ] No secrets in commit
- [ ] Docs in `docs/` if behavior changed
- [ ] Bump `VERSION` + `CHANGELOG.md` if release

## Known limitations

| Limitation | Detail |
| ---------- | ------ |
| No deduplication | Re-applying creates duplicate entries |
| No automatic undo | Use backups in `backups/` |
| Limited context | 20 reference aliases sent to AI |
