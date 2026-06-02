# Auth and setup flow audit

Date: 2026-05-27

## Bugs addressed

| ID | Issue | Fix |
|----|-------|-----|
| B1 | `-P` failed when env provider differed from override key | `__bashgency_load_env(provider_override)` validates effective provider |
| B2 | `.initialized` without valid API key | Marker only when `__bashgency_env_provider_configured` |
| B3 | Install skipped wizard for invalid non-placeholder keys | `bashgency --configure` + auth error reconfigure |
| B4 | Fragile `sed` env writes | Atomic rewrite in `modules/lib/setup.sh` |
| B5 | Duplicated provider metadata | Single source in `setup.sh` |
| B6 | 401/403 showed raw JSON only | `auth_errors.sh` + interactive recovery |

## Test matrix

| Scenario | Test file |
|----------|-----------|
| Env set/get, special chars | `test/unit/setup_env.bats` |
| Placeholder vs valid env | `test/unit/setup_env.bats`, `first_run.bats` |
| load_env + `-P` override (B1) | `test/unit/load_env.bats` |
| Registry normalize/resolve | `test/unit/registry.bats` |
| Auth error detection/messages | `test/unit/auth_errors.bats` |
| HTTP parse | `test/unit/parse_http.bats` |
| Parser markers/JSON | `test/unit/parser.bats` |
| Run output clean | `test/unit/run_clean.bats` |
| Mock curl 200/401 + headers | `test/unit/http_mock.bats` |
| CLI preview (integration) | `test/integration/cli_preview.bats` |
| Live API smoke | `scripts/test_api.sh` (manual) |

## Run tests

```bash
bash scripts/run_tests.sh
```
