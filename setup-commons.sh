#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "ERROR: line $LINENO: $BASH_COMMAND" >&2' ERR

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

usage() {
  cat <<'EOF'
Usage:
  ./base-setup.sh [--allow-root]

Options:
  --allow-root    root 実行を明示的に許可する。
                  コンテナ内で root のままセットアップしたい場合だけ使う。

Examples:
  ./base-setup.sh
  ./base-setup.sh --allow-root
EOF
}

ALLOW_ROOT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --allow-root)
      ALLOW_ROOT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -eq 0 ] && [ "$ALLOW_ROOT" -ne 1 ]; then
  cat <<'EOF'
このスクリプトは通常ユーザーで実行してください。

理由:
  Nix はユーザーの $HOME 配下に環境を構築するため、
  root で実行すると /root 用の環境になってしまいます。

通常の実行:
  ./base-setup.sh

コンテナ内で root のまま使いたい場合:
  ./base-setup.sh --allow-root
EOF
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  SUDO=()
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo が見つかりません。root で sudo を入れるか、--allow-root で実行してください。" >&2
    exit 1
  fi
  SUDO=(sudo)
fi

ensure_bashrc_line() {
  local line="$1"
  local bashrc="$HOME/.bashrc"

  touch "$bashrc"

  if ! grep -qxF "$line" "$bashrc"; then
    echo "$line" >> "$bashrc"
  fi
}

# Nix インストーラーの実行に curl が必要なため、なければシステム PM で最小限だけ入れる
ensure_curl() {
  if command -v curl >/dev/null 2>&1; then
    return
  fi

  log "curl をインストール (Nix インストーラーのブートストラップ)"

  if command -v apt-get >/dev/null 2>&1; then
    "${SUDO[@]}" apt-get update -qq
    DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y curl ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    "${SUDO[@]}" dnf install -y curl ca-certificates
  elif command -v pacman >/dev/null 2>&1; then
    "${SUDO[@]}" pacman -Sy --needed --noconfirm curl ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    "${SUDO[@]}" apk add --no-cache curl ca-certificates
  elif command -v zypper >/dev/null 2>&1; then
    "${SUDO[@]}" zypper --non-interactive install curl ca-certificates
  else
    echo "curl が見つかりません。curl をインストールしてから再実行してください。" >&2
    exit 1
  fi
}

install_nix() {
  log "Nix をセットアップ"

  if ! command -v nix >/dev/null 2>&1; then
    sh <(curl -fsSL https://nixos.org/nix/install) --no-daemon
  fi

  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi

  if ! command -v nix >/dev/null 2>&1; then
    echo "Nix のインストールに失敗しました。" >&2
    exit 1
  fi

  ensure_bashrc_line '. "$HOME/.nix-profile/etc/profile.d/nix.sh"'
}

install_nix_tools() {
  local tools_file="$1"

  if [ ! -f "$tools_file" ]; then
    echo "Nix tools file not found: $tools_file" >&2
    exit 1
  fi

  log "Nix channel を更新"

  if ! nix-channel --list | grep -q nixpkgs; then
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
  fi
  nix-channel --update

  log "Nix packages をインストール"
  log "Tools file: $tools_file"

  while read -r attr _commands; do
    [ -z "${attr:-}" ] && continue

    log "nix-env -iA ${attr}"
    nix-env -iA "$attr"
  done < <(
    grep -vE '^\s*(#|$)' "$tools_file" \
      | sed -E 's/#.*$//' \
      | awk 'NF'
  )

  hash -r
}

verify_installation() {
  local tools_file="$1"

  log "インストール確認"

  echo "user:   $(whoami)"
  echo "home:   $HOME"
  echo "shell:  ${SHELL:-unknown}"
  echo

  if command -v nix >/dev/null 2>&1; then
    echo "nix:    $(nix --version)"
  else
    echo "nix:    not found"
    return 1
  fi

  echo
  log "nix-env --query"
  nix-env --query || true

  echo
  log "commands"

  local failed=0

  while read -r _attr commands; do
    [ -z "${_attr:-}" ] && continue
    [ -z "${commands:-}" ] && continue

    for cmd in $commands; do
      if command -v "$cmd" >/dev/null 2>&1; then
        printf "OK   %-10s %s\n" "$cmd" "$(command -v "$cmd")"

        case "$cmd" in
          node|npm|npx|go|codex|gemini|claude|gh|podman|nvim)
            "$cmd" --version 2>/dev/null | head -n 1 || true
            ;;
        esac
      else
        printf "NG   %-10s not found\n" "$cmd"
        failed=1
      fi
    done
  done < <(
    grep -vE '^\s*(#|$)' "$tools_file" \
      | sed -E 's/#.*$//' \
      | awk 'NF'
  )

  if [ "$failed" -ne 0 ]; then
    echo
    echo "一部の Nix packages が見つかりません。次を試してください:"
    echo
    echo "  exec bash -l"
    echo "  nix-env --query"
    echo
    return 1
  fi
}

main() {
  local nix_tools_file="${SCRIPT_DIR}/tools/nix.txt"

  ensure_curl
  install_nix
  install_nix_tools "$nix_tools_file"
  verify_installation "$nix_tools_file"

  cat <<'EOF'

セットアップ完了。

現在のターミナルで command not found になる場合:

  exec bash -l

確認:

  nix --version
  nix-env --query
  node -v
  npm -v
  command -v codex
  command -v gemini
  command -v claude

EOF
}

main "$@"
