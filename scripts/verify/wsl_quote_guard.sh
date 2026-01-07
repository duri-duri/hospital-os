#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

SCAN_GLOBS=(
  --glob '!.git/**'
  --glob '!node_modules/**'
  --glob '!dist/**'
  --glob '!build/**'
  --glob '!.next/**'
  --glob '!.turbo/**'
  --glob '!coverage/**'

  --glob '!docs/ops/**'
  --glob '!scripts/verify/wsl_quote_guard.sh'
)

BAD_PATTERN='(?i)\bwsl(\.exe)?\b[^\n]*\bbash\b[^\n]*-lc\s*"'

set +e
hits="$(rg -n --hidden --no-ignore-vcs -S "${SCAN_GLOBS[@]}" -e "$BAD_PATTERN" . 2>&1)"
rc=$?
set -e

if [ $rc -eq 2 ]; then
  echo "ERR: rg failed while scanning" >&2
  echo "$hits" >&2
  exit 2
fi

if [ $rc -eq 0 ]; then
  echo "HARD FAIL: forbidden WSL quoting detected."
  echo
  echo "$hits"
  echo
  echo "Fix: Use single quotes for bash -lc in PowerShell, or use scripts/run-wsl.ps1 + gate.ci.ps1"
  exit 1
fi

echo "OK: WSL quote guard passed (no bash -lc \"...\" found)."
exit 0
