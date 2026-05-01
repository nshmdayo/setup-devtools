#!/usr/bin/env bash
set -Eeuo pipefail

if command -v nix >/dev/null 2>&1; then
  echo "nix is already installed: $(nix --version)"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    echo "Installing Nix for macOS..."
    sh <(curl -L https://nixos.org/nix/install)
    ;;

  Linux)
    if [ "$(id -u)" -eq 0 ]; then
      echo "Do not run this script as root."
      echo "Create a normal user first, then run this script."
      exit 1
    fi

    echo "Installing Nix for Linux..."
    sh <(curl -L https://nixos.org/nix/install) --daemon
    ;;

  *)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

mkdir -p "$HOME/.config/nix"

if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  cat >> "$HOME/.config/nix/nix.conf" <<'EOF'
experimental-features = nix-command flakes
EOF
fi

echo
echo "Nix installation completed."
echo "Restart your shell:"
echo
echo "  exec \$SHELL -l"
