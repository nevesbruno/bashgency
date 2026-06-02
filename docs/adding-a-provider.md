# Adding an AI provider

Bashgency uses a small provider registry under `modules/lib/providers/`. Tier 1 ships four providers; new ones should plug into the same contract without duplicating HTTP or env logic.

## Contract (`registry.sh`)

| Function | Purpose |
| -------- | ------- |
| `__bashgency_provider_list` | Valid provider IDs |
| `__bashgency_provider_resolve` | Normalize ID; default when empty |
| `__bashgency_provider_validate` | Ensure API key env var is set |
| `__bashgency_provider_default_model` | Default `-m` when omitted |
| `__bashgency_provider_key_var` | Env var name for the key |
| `__bashgency_provider_family` | `openai_compat`, `anthropic`, or `gemini` |
| `__bashgency_provider_chat` | Dispatch HTTP; returns `body` + newline + `http_code` |

## Steps

1. **Pick a family**
   - OpenAI-shaped chat completions: extend `openai_compat.sh` + registry `case` (URL + key var).
   - Anthropic Messages API: reuse `anthropic.sh` only if identical; otherwise add a family file.
   - Gemini generateContent: reuse `gemini.sh` or add a sibling family module.

2. **Registry metadata** in `registry.sh`:
   - Add ID to `__bashgency_provider_is_valid`, `__bashgency_provider_list`, `__bashgency_provider_key_var`, `__bashgency_provider_default_model`, `__bashgency_provider_display_name`, `__bashgency_provider_key_hint`.

3. **Env template** — add commented `YOUR_API_KEY` to [`env.example`](../env.example).

4. **Parser** — if response JSON differs, extend `__bashgency_extract_content` / `__bashgency_extract_content_jq` in [`modules/lib/parser.sh`](../modules/lib/parser.sh) for the new family branch.

5. **Install menu** (optional) — add a numbered option in [`install.sh`](../install.sh) using the same `key_var` names as the registry.

6. **Test** — with a real key:

   ```bash
   bash ~/lab/bashgency/scripts/test_api.sh your_provider_id
   ```

## DRY rules

- HTTP: always go through `__bashgency_curl_post_json` in `http.sh`.
- Do not call `curl` from `api.sh`, CLI, or install.
- Do not duplicate provider metadata outside `registry.sh` except install menu labels.

## Tier 1 reference

| ID | Family | Key env | Default model |
| -- | ------ | ------- | ------------- |
| `deepseek` | openai_compat | `DEEPSEEK_API_KEY` | `deepseek-chat` |
| `openai` | openai_compat | `OPENAI_API_KEY` | `gpt-4o-mini` |
| `anthropic` | anthropic | `ANTHROPIC_API_KEY` | `claude-3-5-haiku-latest` |
| `gemini` | gemini | `GEMINI_API_KEY` | `gemini-2.0-flash` |
