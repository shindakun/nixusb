#!/usr/bin/env bash
# Install the dotfiles into the current user's ~/.config.
# Run as the normal user (NOT root), after the first boot.
#
# The niri config is the same file the NixOS side uses (nix/home/niri/). Two
# things are Arch-specific: the Noctalia config, because Arch packages v5 while
# the Air runs v4, and zshrc, because Home Manager generates the shell on the
# NixOS side.
#
#   cd /root/airnix/arch && ./install/dotfiles.sh
#
# Existing files are backed up to <file>.bak before being replaced.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "run this as your normal user, not root" >&2
  exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$HERE/../dotfiles"
SHARED="$HERE/../../nix/home"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

place() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "    backing up existing $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  rm -f "$dest"
  cp "$src" "$dest"
  echo "==> $dest"
}

place "$SHARED/niri/config.kdl"        "$CFG/niri/config.kdl"
# config.kdl includes shell.kdl; v5 is the only Noctalia in the Arch repos.
place "$SHARED/niri/shell-v5.kdl"      "$CFG/niri/shell.kdl"
place "$DOTS/noctalia/config.toml"     "$CFG/noctalia/config.toml"
place "$DOTS/zsh/zshrc"                "$HOME/.zshrc"

mkdir -p "$HOME/Pictures/Screenshots"

echo
echo "==> dotfiles installed."
echo "    Log out and pick the 'niri' session at the greeter (or run: niri --session)."
