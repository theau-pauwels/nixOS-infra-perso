#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a regular sudo-capable user, not as root." >&2
  exit 1
fi

if command -v nix >/dev/null 2>&1; then
  nix --version
  echo "Nix is already installed."
  exit 0
fi

# Use the official multi-user installer on systemd-based Ubuntu hosts.
bash <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # Load nix into the current shell so verification can happen immediately.
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

nix --version
echo "Nix installed. Open a new shell or source the daemon profile before using flakes."
