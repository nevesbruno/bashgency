#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    cp "$(_bashgency_test_root)/test/fixtures/env/valid_deepseek.env" "$BASHGENCY_ENV"
    export PATH="$(_bashgency_test_root)/test/fixtures/bin:$PATH"
    chmod +x "$(_bashgency_test_root)/test/fixtures/bin/curl"
    export BASHGENCY_MOCK_HTTP_CODE=200
    export BASHGENCY_NONINTERACTIVE=1
    touch "$BASHGENCY_DIR/.initialized"
    touch "$BASHGENCY_DIR/aliases.sh"
}

teardown() {
    bashgency_test_teardown_dir
}

@test "bashgency preview succeeds with mocked API" {
    local root cli_out
    root="$(_bashgency_test_root)"
  # shellcheck disable=SC1090
    source "$root/modules/bashgency-cli.sh"
    run bashgency -p "alias t for true" --preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"PREVIEW"* ]] || [[ "$output" == *"ALIAS"* ]]
}
