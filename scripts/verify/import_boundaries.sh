#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "ERR: $1"; exit 1; }

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

# Network lib patterns (hardened: catch usage, imports, requires, and global variants)
# Note: axios is only detected via import/require patterns to avoid false positives
NETWORK_PATTERNS=(
  -e '\bfetch\('
  -e '\b(globalThis|window)\.fetch\('
  -e '\bnode-fetch\b'
  -e '\bundici\b'
  -e '\bfrom\s+['"'"'"]\s*(node-fetch|undici|axios)\s*['"'"'"]'
  -e '\brequire\s*\(\s*['"'"'"]\s*(node-fetch|undici|axios)\s*['"'"'"]\s*\)'
)

# Rule A1: apps/**, packages/ui-kit/**, packages/business-logic/** - forbid network usage
echo "[1/4] Rule A1: apps/ui-kit/business-logic network boundary..."
set +e
out="$(rg_run -n --hidden --no-ignore-vcs -S \
  "${EXCLUDE_GLOB[@]}" \
  --glob "apps/**/*.$CODE_EXT" \
  --glob "packages/ui-kit/**/*.$CODE_EXT" \
  --glob "packages/business-logic/**/*.$CODE_EXT" \
  --glob "!packages/spine-sdk/**" \
  "${NETWORK_PATTERNS[@]}" \
  .)"
rc=$?
set -e
if [ $rc -eq 0 ]; then
  echo "ERR: Rule A1: Direct network usage (fetch/axios/node-fetch/undici) forbidden in apps/**, packages/ui-kit/**, packages/business-logic/**"
  echo "$out"
  exit 1
elif [ $rc -eq 2 ]; then
  echo "ERR: Rule A1: rg command failed" >&2
  exit 1
else
  echo "OK: Rule A1 passed"
fi

# Rule A2: packages/spine-sdk/** - forbid network EXCEPT in transport/**
echo "[2/4] Rule A2: spine-sdk internal boundary (network only in transport/)..."
set +e
out="$(rg_run -n --hidden --no-ignore-vcs -S \
  "${EXCLUDE_GLOB[@]}" \
  --glob "packages/spine-sdk/**/*.$CODE_EXT" \
  --glob '!packages/spine-sdk/transport/**' \
  "${NETWORK_PATTERNS[@]}" \
  .)"
rc=$?
set -e
if [ $rc -eq 0 ]; then
  echo "ERR: Rule A2: Network usage forbidden in packages/spine-sdk/** except packages/spine-sdk/transport/**"
  echo "$out"
  exit 1
elif [ $rc -eq 2 ]; then
  echo "ERR: Rule A2: rg command failed" >&2
  exit 1
else
  echo "OK: Rule A2 passed"
fi

# Rule A3: business-logic purity - browser globals, React, network libs
echo "[3/4] Rule A3: business-logic purity (browser/React/network)..."
set +e
out="$(rg_run -n --hidden --no-ignore-vcs -S \
  "${EXCLUDE_GLOB[@]}" \
  --glob "packages/business-logic/**/*.$CODE_EXT" \
  --glob "!packages/spine-sdk/**" \
  -e '\b(window|document|localStorage)\b' \
  -e "from 'react'" -e 'from "react"' -e "import.*from 'react'" -e 'import.*from "react"' \
  "${NETWORK_PATTERNS[@]}" \
  .)"
rc=$?
set -e
if [ $rc -eq 0 ]; then
  echo "ERR: Rule A3: business-logic must be pure (no window/document/localStorage, React imports, or network libs)"
  echo "$out"
  exit 1
elif [ $rc -eq 2 ]; then
  echo "ERR: Rule A3: rg command failed" >&2
  exit 1
else
  echo "OK: Rule A3 passed"
fi

# Rule A4: apps must not contain obvious domain rule folders
echo "[4/4] Rule A4: app domain-rules folder scan..."
set +e
found_dirs=$(find apps -type d \( -name 'domain_rules' -o -name 'business_logic' -o -name 'pricing_rules' -o -name 'state_machine' \) 2>/dev/null)
rc=$?
set -e
if [ $rc -eq 0 ] && [ -n "$found_dirs" ]; then
  echo "ERR: Rule A4: Apps must not own domain rule folders"
  echo "$found_dirs"
  exit 1
else
  echo "OK: Rule A4 passed"
fi

echo "OK: boundary scan passed (v0.3 HARD FAIL gate)"
