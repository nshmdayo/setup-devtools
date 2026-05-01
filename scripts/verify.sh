#!/usr/bin/env bash
set -Eeuo pipefail

commands=(
  git
  gh
  nvim
  jq
  rg
  fd
  fzf
  node
  npm
  npx
  go
  codex
  gemini
  claude
)

failed=0

echo "user: $(whoami)"
echo "home: $HOME"
echo "shell: ${SHELL:-unknown}"
echo

for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "OK %-10s %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "NG %-10s not found\n" "$cmd"
    failed=1
  fi
done

echo

if [ "$failed" -ne 0 ]; then
  echo "Some commands are missing."
  exit 1
fi

echo "All checks passed."
