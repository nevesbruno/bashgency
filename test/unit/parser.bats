#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_setup_dir
    bashgency_test_source_parser
    export BASHGENCY_ACTIVE_PROVIDER=deepseek
}

teardown() {
    bashgency_test_teardown_dir
}

@test "parse_field extracts alias parts" {
    [ "$(__bashgency_parse_field 'ALIAS :: gst :: git status' 2)" = "gst" ]
    [ "$(__bashgency_parse_field 'ALIAS :: gst :: git status' 3)" = "git status" ]
}

@test "parse_type returns marker type" {
    [ "$(__bashgency_parse_type 'FUNCTION :: foo :: echo hi')" = "FUNCTION" ]
}

@test "extract_content from openai success fixture" {
    local body root content
    root="$(_bashgency_test_root)"
    body=$(cat "$root/test/fixtures/json/openai_success.json")
    content=$(__bashgency_extract_content "$body")
    [[ "$content" == *"ALIAS :: t :: true"* ]]
}

@test "sanitize_json_body strips leading garbage" {
    local clean
    clean=$(__bashgency_sanitize_json_body 'noise{"a":1}')
    [ "$clean" = '{"a":1}' ]
}
