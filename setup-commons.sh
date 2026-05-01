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
  mise / node / codex / gemini / claude はユーザーの $HOME 配下に入るため、
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

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo "unsupported"
  fi
}

read_package_file() {
  local file="$1"

  grep -vE '^\s*(#|$)' "$file" \
    | sed -E 's/#.*$//' \
    | awk 'NF'
}

install_packages() {
  local pm="$1"
  local package_file="$2"

  if [ ! -f "$package_file" ]; then
    echo "Package file not found: $package_file" >&2
    exit 1
  fi

  mapfile -t packages < <(read_package_file "$package_file")

  if [ "${#packages[@]}" -eq 0 ]; then
    log "No packages to install: $package_file"
    return
  fi

  log "Package manager: $pm"
  log "Package file: $package_file"

  case "$pm" in
    apt)
      "${SUDO[@]}" apt-get update
      DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y "${packages[@]}"
      ;;

    dnf)
      "${SUDO[@]}" dnf install -y "${packages[@]}"
      ;;

    pacman)
      "${SUDO[@]}" pacman -Syu --needed --noconfirm "${packages[@]}"
      ;;

    apk)
      "${SUDO[@]}" apk update
      "${SUDO[@]}" apk add --no-cache "${packages[@]}"
      ;;

    zypper)
      "${SUDO[@]}" zypper --non-interactive refresh
      "${SUDO[@]}" zypper --non-interactive install "${packages[@]}"
      ;;

    *)
      echo "Unsupported package manager: $pm" >&2
      exit 1
      ;;
  esac
}

ensure_bashrc_line() {
  local line="$1"
  local bashrc="$HOME/.bashrc"

  touch "$bashrc"

  if ! grep -qxF "$line" "$bashrc"; then
    echo "$line" >> "$bashrc"
  fi
}

install_mise() {
  log "mise をセットアップ"

  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v mise >/dev/null 2>&1; then
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! command -v mise >/dev/null 2>&1; then
    echo "mise のインストールに失敗しました。" >&2
    exit 1
  fi

  ensure_bashrc_line 'export PATH="$HOME/.local/bin:$PATH"'
  ensure_bashrc_line 'eval "$(mise activate bash)"'

  eval "$(mise activate bash)"
  hash -r
}

install_mise_tools() {
  log "Node.js 24 と AI CLI tools を mise 経由でインストール"

  # カレントディレクトリに .mise.toml があると global 設定の確認がややこしくなるため HOME で実行する
  local current_dir
  current_dir="$(pwd)"
  cd "$HOME"

  mise use --global node@24
  mise use --global npm:@openai/codex
  mise use --global npm:@google/gemini-cli
  mise use --global npm:@anthropic-ai/claude-code

  mise install

  cd "$current_dir"

  eval "$(mise activate bash)"
  hash -r
}

verify_installation() {
  log "インストール確認"

  echo "shell:  ${SHELL:-unknown}"
  echo "user:   $(whoami)"
  echo "home:   $HOME"
  echo

  echo "mise:   $(mise --version)"
  echo "node:   $(node -v)"
  echo "npm:    $(npm -v)"

  if command -v gh >/dev/null 2>&1; then
    echo "gh:     $(gh --version | head -n 1)"
  else
    echo "gh:     not found"
  fi

  echo
  command -v podman || true
  command -v nvim || true
  command -v codex || true
  command -v gemini || true
  command -v claude || true

  echo
  codex --version || true
  gemini --version || true
  claude --version || true
}

main() {
  local pm
  pm="$(detect_package_manager)"

  if [ "$pm" = "unsupported" ]; then
    echo "対応している package manager が見つかりません: apt, dnf, pacman, apk, zypper" >&2
    exit 1
  fi

  local package_file="${SCRIPT_DIR}/packages/${pm}.txt"

  install_packages "$pm" "$package_file"
  install_mise
  install_mise_tools
  verify_installation

  cat <<'EOF'

セットアップ完了。

現在のターミナルで command not found になる場合:

  exec bash -l

確認:

  mise current
  node -v
  npm -v
  command -v codex
  command -v gemini
  command -v claude

EOF
}

main "$@"
