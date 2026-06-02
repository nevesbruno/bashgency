#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    bashgency_test_source_stack
}

teardown() {
    bashgency_test_teardown_dir
}

@test "placeholder env is not considered configured" {
    cp "$(_bashgency_test_root)/test/fixtures/env/placeholder.env" "$BASHGENCY_ENV"
    run __bashgency_env_provider_configured "$BASHGENCY_ENV"
    [ "$status" -eq 1 ]
}

@test "valid env is configured" {
    cp "$(_bashgency_test_root)/test/fixtures/env/valid_deepseek.env" "$BASHGENCY_ENV"
    run __bashgency_env_provider_configured "$BASHGENCY_ENV"
    [ "$status" -eq 0 ]
}

@test "initialized marker should not be created for placeholder-only env" {
    cp "$(_bashgency_test_root)/test/fixtures/env/placeholder.env" "$BASHGENCY_ENV"
    touch "$BASHGENCY_DIR/aliases.sh"
    marker="$BASHGENCY_DIR/.initialized"
    rm -f "$marker"
    run __bashgency_env_provider_configured "$BASHGENCY_ENV"
    [ "$status" -eq 1 ]
    [ ! -f "$marker" ]
}
