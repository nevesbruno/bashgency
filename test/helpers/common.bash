# Common helpers for Bashgency bats tests

_bashgency_test_root() {
    local dir
    dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    printf '%s' "$dir"
}

bashgency_test_setup_dir() {
    export BASHGENCY_DIR
    BASHGENCY_DIR="$(mktemp -d)"
    export BASHGENCY_ENV="$BASHGENCY_DIR/env"
    mkdir -p "$BASHGENCY_DIR/modules" "$BASHGENCY_DIR/backups"
}

bashgency_test_teardown_dir() {
    [ -n "${BASHGENCY_DIR:-}" ] && [ -d "$BASHGENCY_DIR" ] && rm -rf "$BASHGENCY_DIR"
}

bashgency_test_source_module() {
    local root mod
    root="$(_bashgency_test_root)"
    mod="$1"
    # shellcheck disable=SC1090
    source "$root/modules/lib/$mod"
}

bashgency_test_source_stack() {
    local root="$(_bashgency_test_root)"
    # shellcheck disable=SC1090
    source "$root/modules/lib/colors.sh"
    source "$root/modules/lib/core.sh"
    source "$root/modules/lib/setup.sh"
    source "$root/modules/lib/providers/registry.sh"
}

bashgency_test_source_parser() {
    bashgency_test_source_stack
    # shellcheck disable=SC1090
    source "$(_bashgency_test_root)/modules/lib/parser.sh"
}

bashgency_test_source_api() {
    bashgency_test_source_parser
    # shellcheck disable=SC1090
    source "$(_bashgency_test_root)/modules/lib/api.sh"
}

bashgency_test_source_auth() {
    bashgency_test_source_api
    # shellcheck disable=SC1090
    source "$(_bashgency_test_root)/modules/lib/auth_errors.sh"
}
