#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UCODE="${UCODE:-ucode}"

export HAPPWRT_ROOT="$ROOT"
export UCODE

"$UCODE" "$ROOT/tests/test_parse.uc"
"$UCODE" "$ROOT/tests/test_gen.uc"

echo "all tests passed"
