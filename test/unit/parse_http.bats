#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_source_api
}

@test "parse_http_response splits body and code" {
    local parsed code body
    parsed=$(__bashgency_parse_http_response $'{"ok":true}\n200')
    code=$(printf '%s' "$parsed" | head -n1)
    body=$(printf '%s' "$parsed" | tail -n +2)
    [ "$code" = "200" ]
    [ "$body" = '{"ok":true}' ]
}

@test "parse_http_response handles multiline body" {
    local parsed code
    parsed=$(__bashgency_parse_http_response $'line1\nline2\n401')
    code=$(printf '%s' "$parsed" | head -n1)
    [ "$code" = "401" ]
}
