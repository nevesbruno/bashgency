#!/usr/bin/env bats

load '../helpers/common'

setup() {
    bashgency_test_source_stack
}

@test "normalize_id lowercases and strips CR" {
    [ "$(__bashgency_provider_normalize_id 'DeepSeek')" = "deepseek" ]
    [ "$(__bashgency_provider_normalize_id $'openai\r')" = "openai" ]
}

@test "resolve accepts known providers" {
    [ "$(__bashgency_provider_resolve deepseek)" = "deepseek" ]
    [ "$(__bashgency_provider_resolve OPENAI)" = "openai" ]
}

@test "resolve rejects unknown provider" {
    run __bashgency_provider_resolve notaprovider
    [ "$status" -eq 1 ]
}

@test "family mapping" {
    [ "$(__bashgency_provider_family deepseek)" = "openai_compat" ]
    [ "$(__bashgency_provider_family anthropic)" = "anthropic" ]
    [ "$(__bashgency_provider_family gemini)" = "gemini" ]
}

@test "key_var names" {
    [ "$(__bashgency_provider_key_var openai)" = "OPENAI_API_KEY" ]
    [ "$(__bashgency_provider_key_var gemini)" = "GEMINI_API_KEY" ]
}
