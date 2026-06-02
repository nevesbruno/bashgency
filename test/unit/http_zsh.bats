#!/usr/bin/env bats

load '../helpers/common'

# zsh + emulate sh: local array names must not be passed to curl helper (regression 401 governor)

@test "zsh http helper passes Authorization to mock curl" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not installed"

    local root
    root="$(_bashgency_test_root)"
    export BASHGENCY_MOCK_LOG_HEADERS=1
    export BASHGENCY_MOCK_HEADER_LOG="$BATS_TMPDIR/zsh-headers.log"
    rm -f "$BASHGENCY_MOCK_HEADER_LOG"

    zsh -f -c '
        set -e
        emulate -L sh
        root="'"$root"'"
        export PATH="'"$root"'/test/fixtures/bin:$PATH"
        export BASHGENCY_MOCK_HTTP_CODE=200
        export BASHGENCY_MOCK_LOG_HEADERS=1
        export BASHGENCY_MOCK_HEADER_LOG="'"$BASHGENCY_MOCK_HEADER_LOG"'"
        export BASHGENCY_ENV="'"$root"'/test/fixtures/env/valid_deepseek.env"
        set -a
        source "$BASHGENCY_ENV"
        set +a
        source "$root/modules/lib/providers/http.sh"
        http_headers=$(printf "%s\n" \
            "Content-Type: application/json" \
            "Authorization: Bearer $DEEPSEEK_API_KEY")
        resp=$(__bashgency_curl_post_json "https://api.deepseek.com/chat/completions" "$http_headers" "{\"model\":\"deepseek-chat\"}")
        code=$(printf "%s" "$resp" | tail -n1)
        [[ "$code" == "200" ]] || exit 1
    '

    grep -q 'Authorization: Bearer sk-test-valid-key' "$BASHGENCY_MOCK_HEADER_LOG"
}
