#!/usr/bin/env bash
#
# Build and run the headless MuTerm unit tests.
#
# Usage:
#   ./tests/run-tests.sh
#   FPC=/path/to/fpc ./tests/run-tests.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

FPC="${FPC:-}"
if [ -z "$FPC" ]; then
  if command -v fpc >/dev/null 2>&1; then
    FPC="fpc"
  elif [ -x "$HOME/fpcupdeluxe/fpc/bin/x86_64-linux/fpc.sh" ]; then
    # fpcupdeluxe keeps its own fpc.cfg; fpc.sh points the compiler at it.
    FPC="$HOME/fpcupdeluxe/fpc/bin/x86_64-linux/fpc.sh"
  fi
fi

if [ -z "$FPC" ] || ! command -v "$FPC" >/dev/null 2>&1; then
  echo "fpc bulunamadi. FPC=... ile yolu belirtin." >&2
  exit 127
fi

BUILD_DIR="${TMPDIR:-/tmp}/muterm-tests"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/units"

"$FPC" -B -vw \
  -Fu. -Futests \
  -FU"$BUILD_DIR/units" \
  -FE"$BUILD_DIR" \
  tests/MuTests.lpr

"$BUILD_DIR/MuTests" "$@"
