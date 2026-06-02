#!/usr/bin/env bats

load '../helpers/common'

setup() {
    # shellcheck disable=SC1090
    source "$(_bashgency_test_root)/modules/lib/run.sh"
}

@test "clean_run_output strips markdown fences" {
    local out
    out=$(__bashgency_clean_run_output $'```bash\nls -la\n```')
    [ "$out" = "ls -la" ]
}

@test "clean_run_output removes blank lines" {
    local out
    out=$(__bashgency_clean_run_output $'echo hi\n\n\necho bye')
    [ "$out" = $'echo hi\necho bye' ]
}
