# Developer Guide - Bashgency

## Architecture

```
~/lab/bashgency/modules/bashgency-cli.sh  (repo)
        |
        +-- bashgency()              # main CLI (entry point)
        +-- lib/
        |     +-- providers/         # AI connector registry
        |     |     +-- registry.sh, http.sh, openai_compat, anthropic, gemini
        |     +-- api.sh             # prompts + __bashgency_call_api_raw (delegates)
        |     |     +-- __bashgency_call_api_raw()  # -> __bashgency_provider_chat
        |     |     +-- __bashgency_call_api()      # alias wrapper
        |     +-- run.sh             # semantic command execution
        |     |     +-- __bashgency_run_flow()
        |     |     +-- __bashgency_run_command()
        |     |     +-- __bashgency_build_run_system_prompt()
        |     |     +-- __bashgency_clean_run_output()
        |     +-- apply.sh          # alias/function/module writer
        |     +-- parser.sh         # AI output parsing
        |     +-- ui.sh             # panels, previews, menus
        |     +-- io.sh             # backup, history
        |     +-- colors.sh         # tput colors
        |     +-- core.sh           # config paths, env
        |     +-- env.sh            # first-run detection
        |     +-- inventory.sh      # inventory browser
        |
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
| `__bashgency_provider_chat` | HTTP via active provider (registry) |
| `__bashgency_call_api_raw` | Delegates to provider chat |
| `__bashgency_run_flow` | Run mode orchestrator |
| `__bashgency_run_command` | Execute command + audit log |
| `__bashgency_build_run_system_prompt` | Run mode system prompt |
| `__bashgency_clean_run_output` | Strip markdown from AI response |

## AI output format

### Alias/function/module mode

```
ALIAS :: name :: command
FUNCTION :: name :: function name(){ ... }
MODULE :: name :: file_content :: source ~/.config/bashgency/modules/name.sh
```

Separator: ` :: `

### Run mode

Raw shell command (no marker). The system prompt demands pure command output:

```
grep -rl "query" --include="*.txt" .
```

Cleaned via `__bashgency_clean_run_output()` (strips markdown fences, empty lines).

## API integration

Providers live in `modules/lib/providers/`. Tier 1: `deepseek`, `openai`, `anthropic`, `gemini`.

**Context:** first 150 lines of the aliases file, filter `^(function|alias)`, max 20 entries (alias mode only).

**Reuse:** `__bashgency_call_api_raw(system_prompt, user_prompt, model)` delegates to `__bashgency_provider_chat`.

**Adding providers:** see [`adding-a-provider.md`](adding-a-provider.md).

## Variables

| Variable | Default | Usage |
| -------- | ------- | ----- |
| `BASHGENCY_DIR` | `$HOME/.config/bashgency` | Config root |
| `BASHGENCY_PROVIDER` | `deepseek` | Active AI provider |
| `BASHGENCY_TARGET` | (empty) | Aliases file override |
| `*_API_KEY` | in `env` | Per-provider authentication |

### `__bashgency_aliases_path` (priority)

1. `BASHGENCY_TARGET` (from `env` or environment)
2. `$BASHGENCY_DIR/aliases.sh` (creates if missing)

## How to extend

### Add a new command type (e.g. `sudo`, `docker exec` loops)

1. Add a new system prompt builder in a new or existing `lib/*.sh`
2. Use `__bashgency_call_api_raw()` with the custom prompt
3. Add a flag in `bashgency-cli.sh` and route to your flow

### Change aliases destination

In `~/.config/bashgency/env`:

```bash
BASHGENCY_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```

### Switch AI provider

Set in `~/.config/bashgency/env`:

```bash
BASHGENCY_PROVIDER="anthropic"
ANTHROPIC_API_KEY="sk-ant-..."
```

Or per command: `bashgency -P openai -p "..."`.

## Local development

```bash
bash ~/lab/bashgency/scripts/run_tests.sh
bash ~/lab/bashgency/scripts/test_api.sh
bash ~/lab/bashgency/scripts/test_api.sh gemini
source ~/lab/bashgency/modules/bashgency-cli.sh
bashgency -p "alias test for echo ok" --preview
```

Sandbox:

```bash
export BASHGENCY_DIR="/tmp/bashgency-test"
mkdir -p "$BASHGENCY_DIR/modules" "$BASHGENCY_DIR/backups"
```

## PR checklist

- [ ] Change in `modules/`
- [ ] `bashgency -p "..." --preview` works
- [ ] `bashgency -r "..." -y` works (when applicable)
- [ ] No secrets in commit
- [ ] Docs in `docs/` if behavior changed
- [ ] Bump `VERSION` + `CHANGELOG.md` if release

## Known limitations

| Limitation | Detail |
| ---------- | ------ |
| No deduplication | Re-applying creates duplicate entries |
| No automatic undo | Use backups in `backups/` |
| Limited context | 20 reference aliases sent to AI |
| Run mode: single command | Complex multi-step scripts still better as MODULE |
