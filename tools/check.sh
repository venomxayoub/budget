#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"
readonly APP_DIR="$REPO_ROOT/budget_manager"
readonly MIN_COVERAGE="${MIN_COVERAGE:-80.0}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '\n==> %s\n' "$*"
}

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  FLUTTER_BIN="$HOME/.local/share/flutter/bin/flutter"
fi

[[ -x "$FLUTTER_BIN" ]] || die "Flutter was not found at $FLUTTER_BIN. Set FLUTTER_BIN."

cd "$REPO_ROOT"

log "Checking whitespace"
git diff --check

log "Resolving Flutter packages"
cd "$APP_DIR"
"$FLUTTER_BIN" pub get

log "Analyzing Dart code"
"$FLUTTER_BIN" analyze --no-pub

log "Running tests with coverage"
"$FLUTTER_BIN" test --no-pub --coverage --concurrency=1

log "Checking coverage threshold"
[[ -s coverage/lcov.info ]] || die "coverage/lcov.info was not created"

ACTUAL_COVERAGE="$(
  awk -F: '
    /^LH:/ { hit += $2 }
    /^LF:/ { found += $2 }
    END {
      if (found == 0) {
        print "0.00"
      } else {
        printf "%.2f", (hit / found) * 100
      }
    }
  ' coverage/lcov.info
)"

awk -v actual="$ACTUAL_COVERAGE" -v minimum="$MIN_COVERAGE" '
  BEGIN { exit(actual + 0 >= minimum + 0 ? 0 : 1) }
' || die "Coverage ${ACTUAL_COVERAGE}% is below required ${MIN_COVERAGE}%"

printf 'Coverage: %s%% (minimum %s%%)\n' "$ACTUAL_COVERAGE" "$MIN_COVERAGE"
