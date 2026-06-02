#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    bashgency_test_source_auth
    export BASHGENCY_ACTIVE_PROVIDER=deepseek
}

teardown() {
    bashgency_test_teardown_dir
}

@test "http_is_auth_error detects 401 and 403" {
    __bashgency_http_is_auth_error 401
    __bashgency_http_is_auth_error 403
    ! __bashgency_http_is_auth_error 429
    ! __bashgency_http_is_auth_error 500
}

@test "http_error_summary parses openai 401 fixture" {
    local body root
    root="$(_bashgency_test_root)"
    body=$(cat "$root/test/fixtures/json/openai_error_401.json")
    msg=$(__bashgency_http_error_summary 401 "$body" openai_compat)
    [[ "$msg" == *"Incorrect API key"* ]]
}

@test "http_error_summary parses anthropic 403 fixture" {
    local body root
    root="$(_bashgency_test_root)"
    body=$(cat "$root/test/fixtures/json/anthropic_error_403.json")
    msg=$(__bashgency_http_error_summary 403 "$body" anthropic)
    [[ "$msg" == *"authentication"* ]] || [[ "$msg" == *"x-api-key"* ]]
}

@test "handle_http_error noninteractive returns 2 on auth error" {
    export BASHGENCY_NONINTERACTIVE=1
    local body root
    root="$(_bashgency_test_root)"
    body=$(cat "$root/test/fixtures/json/openai_error_401.json")
    run __bashgency_handle_http_error 401 "$body" deepseek
    [ "$status" -eq 2 ]
}
