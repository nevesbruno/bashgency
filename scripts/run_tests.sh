#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BATS_BIN=""
if command -v bats >/dev/null 2>&1; then
    BATS_BIN=bats
elif [ -x /tmp/bats-core/bin/bats ]; then
    BATS_BIN=/tmp/bats-core/bin/bats
else
    echo "[*] Installing bats-core to /tmp/bats-core..."
    git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
    BATS_BIN=/tmp/bats-core/bin/bats
fi

chmod +x test/fixtures/bin/curl 2>/dev/null || true

echo "[*] Running unit tests..."
"$BATS_BIN" test/unit/

if [ -d test/integration ] && [ -n "$(find test/integration -name '*.bats' 2>/dev/null | head -1)" ]; then
    echo "[*] Running integration tests..."
    "$BATS_BIN" test/integration/
fi

echo "[+] All tests passed."
