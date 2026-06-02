#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    bashgency_test_source_stack
}

teardown() {
    bashgency_test_teardown_dir
}

@test "load_env fails when env file missing" {
    run __bashgency_load_env
    [ "$status" -eq 1 ]
}

@test "load_env fails on placeholder key" {
    cp "$(_bashgency_test_root)/test/fixtures/env/placeholder.env" "$BASHGENCY_ENV"
    run __bashgency_load_env
    [ "$status" -eq 1 ]
}

@test "load_env succeeds with valid provider" {
    cp "$(_bashgency_test_root)/test/fixtures/env/valid_deepseek.env" "$BASHGENCY_ENV"
    __bashgency_load_env
    [ "$BASHGENCY_ACTIVE_PROVIDER" = "deepseek" ]
}

@test "load_env -P override uses other provider key (regression B1)" {
    cp "$(_bashgency_test_root)/test/fixtures/env/wrong_provider.env" "$BASHGENCY_ENV"
    __bashgency_load_env deepseek
    [ "$BASHGENCY_ACTIVE_PROVIDER" = "deepseek" ]
}

@test "load_env without override fails when active provider lacks key" {
    cp "$(_bashgency_test_root)/test/fixtures/env/wrong_provider.env" "$BASHGENCY_ENV"
    run __bashgency_load_env
    [ "$status" -eq 1 ]
}
