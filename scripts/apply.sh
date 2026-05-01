#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${1:-dev-linux}"

echo "Applying Home Manager profile: ${PROFILE}"

nix build ".#homeConfigurations.${PROFILE}.activationPackage"
./result/activate

echo
echo "Applied: ${PROFILE}"
