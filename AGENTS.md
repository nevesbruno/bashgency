# AGENTS.md - Bashgency

## Stack

- Shell: bash/zsh
- HTTP: curl + jq (+ python3 fallback for JSON)
- API: multi-provider via `modules/lib/providers/` (Tier 1: deepseek, openai, anthropic, gemini)

## Layout

| Path | Role |
| ---- | ---- |
| `modules/bashgency-cli.sh` | Entry point (sources `lib/*.sh`) |
| `modules/lib/` | core modules + `setup.sh`, `auth_errors.sh`, `providers/` |
| `test/unit/` | bats unit tests (offline) |
| `scripts/run_tests.sh` | run bats suite |
| `~/.config/bashgency/env` | Secrets (never commit) |
| `~/.config/bashgency/aliases.sh` | Default destination for generated aliases |
| `~/.config/bashgency/modules/` | AI-generated shell modules |
| `~/.config/bashgency/history` | Append-only log |
| `~/.config/bashgency/backups/` | Pre-write backups |

## Installation

```bash
git clone <repo> ~/lab/bashgency
bash ~/lab/bashgency/install.sh
# Edit ~/.config/bashgency/env: BASHGENCY_PROVIDER + matching *_API_KEY
```

Typical integration via [bash-stuffs](https://github.com/nevesbruno/bash-stuffs) `alias.sh`:

```bash
source "$HOME/lab/bashgency/modules/bashgency-cli.sh"
```

## Code conventions

- Internal functions: `__bashgency_` prefix
- AI output: `ALIAS ::`, `FUNCTION ::`, `MODULE ::` with ` :: ` separator
- Minimal diffs; never commit `env` or API keys
- Bump `VERSION` + `CHANGELOG.md` on releases

## Quick tests

```bash
bash ~/lab/bashgency/scripts/run_tests.sh
source ~/lab/bashgency/modules/bashgency-cli.sh
bashgency -p "alias x for echo ok" --preview
bashgency -P openai -p "alias x for echo ok" --preview
bashgency --configure
bash ~/lab/bashgency/scripts/test_api.sh
bash ~/lab/bashgency/scripts/test_api.sh anthropic
```

## Destination override

In `~/.config/bashgency/env`:

```bash
BASHGENCY_TARGET="$HOME/lab/bash-stuffs/alias.sh"
```
