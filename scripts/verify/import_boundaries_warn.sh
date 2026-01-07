#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ripgrep wrapper: exit 0=match, 1=no match, 2=error
rg_run() {
  local out rc
  out="$(rg "$@" 2>&1)"; rc=$?
  if [ $rc -ne 0 ] && [ $rc -ne 1 ]; then
    echo "ERR: rg failed (rc=$rc)" >&2
    echo "CMD: rg $*" >&2
    echo "$out" >&2
    return 2
  fi
  # rc=0(매치) 또는 rc=1(노매치)면 out은 정상 출력(있을 수도/없을 수도)
  printf "%s" "$out"
  return $rc
}

cd "$ROOT"

# Exclude vendor/build outputs
EXCLUDE_GLOB=(
  --glob '!node_modules/**'
  --glob '!dist/**'
  --glob '!build/**'
  --glob '!.next/**'
  --glob '!.turbo/**'
  --glob '!.vite/**'
  --glob '!coverage/**'
  --glob '!.cache/**'
)

# Code file extensions
CODE_EXT='{ts,tsx,js,jsx,py}'

# WARN rule: packages/spine-sdk/transport/** - recommend axios, warn on fetch/node-fetch/undici
# Patterns for non-axios network usage
WARN_PATTERNS=(
  -e '\bfetch\('
  -e '\b(globalThis|window)\.fetch\('
  -e '\bnode-fetch\b'
  -e '\bundici\b'
  -e '\bfrom\s+['"'"'"]\s*(node-fetch|undici)\s*['"'"'"]'
  -e '\brequire\s*\(\s*['"'"'"]\s*(node-fetch|undici)\s*['"'"'"]\s*\)'
)

TOTAL_WARN=0

# Check for non-axios patterns in transport/**
set +e
out="$(rg_run -n --hidden --no-ignore-vcs -S \
  "${EXCLUDE_GLOB[@]}" \
  --glob "packages/spine-sdk/transport/**/*.$CODE_EXT" \
  "${WARN_PATTERNS[@]}" \
  .)"
rc=$?
set -e
if [ $rc -eq 2 ]; then
  echo "ERR: rg command failed" >&2
  exit 1
fi
if [ -n "$out" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      echo "WARN: $line"
      TOTAL_WARN=$((TOTAL_WARN + 1))
    fi
  done <<< "$out"
fi

# Only print total if there are warnings (quiet exit when N=0)
if [ "$TOTAL_WARN" -gt 0 ]; then
  echo "WARN: total=$TOTAL_WARN"
fi

# Always exit 0 (WARN-only guidance)
exit 0
