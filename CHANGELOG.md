# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.6.0] - 2026-05-27

### Added

- `modules/lib/setup.sh`: unified env read/write and provider configuration wizard
- `modules/lib/auth_errors.sh`: auth-aware HTTP errors (401/403) with optional reconfigure + one retry
- `bashgency --configure` / menu option to set provider and API key interactively
- Bats unit/integration tests under `test/`; `scripts/run_tests.sh`
- Audit doc: `docs/auth-setup-audit/auth-setup-audit.md`

### Fixed

- `__bashgency_load_env` validates provider from `-P` override (not only `BASHGENCY_PROVIDER` in env)
- `.initialized` marker only when API key is configured (not placeholder)
- CRLF trimming on provider id from env file

### Changed

- `install.sh` uses `setup.sh` for atomic env updates
- First-run may prompt for API key when TTY is available

## [1.5.0] - 2026-05-27

### Added

- Multi-provider connectors: DeepSeek, OpenAI, Anthropic, Google Gemini
- `modules/lib/providers/`: registry, HTTP helper, and family modules (openai_compat, anthropic, gemini)
- CLI flag `-P` / `--provider` to override `BASHGENCY_PROVIDER` per invocation
- Install step 2/4: interactive provider selection and API key setup
- `docs/adding-a-provider.md` for contributing new connectors
- `scripts/test_api.sh` accepts optional provider ID argument

### Changed

- `BASHGENCY_PROVIDER` in `~/.config/bashgency/env` selects the active provider
- `__bashgency_load_env` validates provider + matching API key via registry
- `api.sh` delegates HTTP to `__bashgency_provider_chat`; parser branches by provider family
- Default model is per-provider (override with `-m`)

## [1.4.2] - 2026-05-27

### Changed

- Logo icon: cursor agent eyes animate side-to-side with 1.5s hold and smooth easing between positions

## [1.4.1] - 2026-05-27

### Added

- Brand SVG assets: `docs/bashgency-logo.svg` (animated cursor agent icon) and `docs/bashgency-wordmark.svg` (logotype + tagline)
- README header: wordmark and animated icon replace plain-text title

## [1.3.0] - 2026-05-27

### Added

- First-run detection: auto-detects shell (bash/zsh) and OS (linux/macos) on initial execution
- Interactive setup prompt: guides user through config file, API key, and rc file configuration
- Automatic rc sourcing: adds `source` lines for `bashgency-cli.sh` and `aliases.sh` to `.bashrc`/`.zshrc`
- Marker file (`~/.config/bashgency/.initialized`) to skip first-run check on subsequent calls
- `__bashgency_detect_shell()` - identifies current shell and rc file path
- `__bashgency_detect_os()` - identifies operating system
- `__bashgency_first_run_check()` - orchestrates setup flow
- `__bashgency_escape_grep()` - helper for grep path escaping

## [1.4.0] - 2026-05-27

### Added

- `-r/--run` flag: semantic terminal execution — describe a task in natural language and bashgency generates, previews, and runs the shell command
- `-y/--yes` flag: auto-confirm command execution, skips the approval prompt
- `modules/lib/run.sh`: new module (`__bashgency_run_flow`, `__bashgency_run_command`, `__bashgency_build_run_system_prompt`, `__bashgency_clean_run_output`)
- `COMMAND` entries in `~/.config/bashgency/history` for audit trail
- Interactive prompt for `bashgency -r` when no description is provided

### Changed

- `modules/lib/api.sh`: extracted `__bashgency_call_api_raw()` for DRY reuse across alias and run flows
- Repository renamed from `ai-alias` to `bashgency`; code lives in `~/lab/bashgency`
- CLI command renamed from `ai-alias` to `bashgency`
- Config directory moved from `~/.config/ai-alias` to `~/.config/bashgency`
- Environment variables renamed: `AI_ALIAS_*` -> `BASHGENCY_*`
- Internal functions renamed: `__ai_*` -> `__bashgency_*`

### Fixed

- `modules/bashgency-cli.sh`: lib path resolution now works in zsh (`BASH_SOURCE` fallback to `$0` + guarded `source` with dir check)

## [1.2.1] - 2026-05-20

### Changed

- README consolidated with user guide (user-first)
- Open source contribution section with link to developer guide
- `user-guide.md` reduced to redirect to README

## [1.2.0] - 2026-05-20

### Added

- Full documentation (user guide, developer guide, CLI reference)
- `scripts/test_api.sh` to validate DeepSeek API connection
- Interactive post-generation menu (apply / retry / exit)
- Preview panels (`query`, `generated`, `action`)
- JSON parse fallback via `python3` in `__bashgency_extract_content`
- Random farewell messages on exit

### Changed

- Refactored `bashgency-cli.sh` module (UI, multiline parser, apply flow)
- API endpoint updated to `https://api.deepseek.com/chat/completions`
- `--force` applies without confirmation; interactive loop with retry

## [1.1.0] - 2025-10-10

### Added

- Debug mode (`BASHGENCY_DEBUG=1`)
- Parser accepts `::` and `|` separators
- Automatic backups before applying changes
- Creation history in `~/.config/bashgency/history`

### Fixed

- Variable `i` leaking to terminal
- curl call and HTTP response extraction

## [1.0.0] - 2025-10-06

### Added

- `bashgency` CLI with DeepSeek integration
- Generation of aliases, functions, and shell modules
