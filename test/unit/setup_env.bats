#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    bashgency_test_source_module setup.sh
}

teardown() {
    bashgency_test_teardown_dir
}

@test "env_set_var writes and updates quoted value" {
    touch "$BASHGENCY_ENV"
    __bashgency_env_set_var FOO bar "$BASHGENCY_ENV"
    [ "$(__bashgency_env_get_var FOO "$BASHGENCY_ENV")" = "bar" ]
    __bashgency_env_set_var FOO baz_qux "$BASHGENCY_ENV"
    [ "$(__bashgency_env_get_var FOO "$BASHGENCY_ENV")" = "baz_qux" ]
}

@test "env_set_var preserves slashes and ampersands in API key" {
    touch "$BASHGENCY_ENV"
    __bashgency_env_set_var DEEPSEEK_API_KEY 'sk-test/key&special=1' "$BASHGENCY_ENV"
    [ "$(__bashgency_env_get_var DEEPSEEK_API_KEY "$BASHGENCY_ENV")" = 'sk-test/key&special=1' ]
}

@test "env_provider_configured rejects placeholder" {
    cp "$(_bashgency_test_root)/test/fixtures/env/placeholder.env" "$BASHGENCY_ENV"
    run __bashgency_env_provider_configured "$BASHGENCY_ENV"
    [ "$status" -eq 1 ]
}

@test "env_provider_configured accepts valid deepseek key" {
    cp "$(_bashgency_test_root)/test/fixtures/env/valid_deepseek.env" "$BASHGENCY_ENV"
    run __bashgency_env_provider_configured "$BASHGENCY_ENV"
    [ "$status" -eq 0 ]
}

@test "provider_key_ok_for checks specific provider" {
    cp "$(_bashgency_test_root)/test/fixtures/env/wrong_provider.env" "$BASHGENCY_ENV"
    run __bashgency_provider_key_ok_for deepseek "$BASHGENCY_ENV"
    [ "$status" -eq 0 ]
    run __bashgency_provider_key_ok_for openai "$BASHGENCY_ENV"
    [ "$status" -eq 1 ]
}
