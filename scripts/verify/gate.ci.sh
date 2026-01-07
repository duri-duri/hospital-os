#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "== Hospital-OS Gate (CI, WSL) =="

echo
echo "[0] WSL quote guard (forbid bash -lc \"...\")"
./scripts/verify/wsl_quote_guard.sh
echo "OK: quote guard passed"

echo
echo "[1] HARD gate: import_boundaries.sh"
./scripts/verify/import_boundaries.sh
echo "HARD_EXIT=0"

echo
echo "[2] WARN gate: import_boundaries_warn.sh"
./scripts/verify/import_boundaries_warn.sh
echo "WARN_EXIT=0"

echo
echo "OK: all gates passed"
