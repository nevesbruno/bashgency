#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    cp "$(_bashgency_test_root)/test/fixtures/env/valid_deepseek.env" "$BASHGENCY_ENV"
    bashgency_test_source_api
    # shellcheck disable=SC1090
    source "$(_bashgency_test_root)/modules/lib/providers/openai_compat.sh"
    export PATH="$(_bashgency_test_root)/test/fixtures/bin:$PATH"
    chmod +x "$(_bashgency_test_root)/test/fixtures/bin/curl"
    export BASHGENCY_MOCK_HTTP_CODE=200
    unset BASHGENCY_MOCK_BODY_FILE BASHGENCY_MOCK_LOG_HEADERS BASHGENCY_MOCK_HEADER_LOG
}

teardown() {
    bashgency_test_teardown_dir
}

@test "mock curl returns 200 with openai-shaped body" {
  set -a
  # shellcheck disable=SC1090
  source "$BASHGENCY_ENV"
  set +a
    local response parsed code
    response=$(__bashgency_openai_compat_chat deepseek "sys" "user" "deepseek-chat")
    parsed=$(__bashgency_parse_http_response "$response")
    code=$(printf '%s' "$parsed" | head -n1)
    [ "$code" = "200" ]
}

@test "mock curl sends Authorization bearer header" {
    export BASHGENCY_MOCK_LOG_HEADERS=1
    export BASHGENCY_MOCK_HEADER_LOG="$BASHGENCY_DIR/headers.log"
    rm -f "$BASHGENCY_MOCK_HEADER_LOG"
    set -a
    # shellcheck disable=SC1090
    source "$BASHGENCY_ENV"
    set +a
    __bashgency_openai_compat_chat deepseek "sys" "user" "deepseek-chat" >/dev/null
    grep -q 'Authorization: Bearer sk-test-valid-key' "$BASHGENCY_MOCK_HEADER_LOG"
}

@test "mock curl can return 401" {
    export BASHGENCY_MOCK_HTTP_CODE=401
    export BASHGENCY_MOCK_BODY_FILE="$(_bashgency_test_root)/test/fixtures/json/openai_error_401.json"
    set -a
    # shellcheck disable=SC1090
    source "$BASHGENCY_ENV"
    set +a
    local response parsed code
    response=$(__bashgency_openai_compat_chat deepseek "sys" "user" "deepseek-chat")
    parsed=$(__bashgency_parse_http_response "$response")
    code=$(printf '%s' "$parsed" | head -n1)
    [ "$code" = "401" ]
}
