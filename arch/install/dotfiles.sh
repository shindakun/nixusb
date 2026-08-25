#!/usr/bin/env bash
# Install the arch/dotfiles/ tree into the current user's ~/.config.
# Run as the normal user (NOT root), after the first boot.
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

place "$DOTS/niri/config.kdl"   "$CFG/niri/config.kdl"
place "$DOTS/waybar/config.jsonc" "$CFG/waybar/config.jsonc"
place "$DOTS/waybar/style.css"  "$CFG/waybar/style.css"
place "$DOTS/zsh/zshrc"         "$HOME/.zshrc"

mkdir -p "$HOME/Pictures/Screenshots"

echo
echo "==> dotfiles installed."
echo "    Log out and pick the 'niri' session at the greeter (or run: niri --session)."
