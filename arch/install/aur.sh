#!/usr/bin/env bash
# Install the AUR exceptions listed in packages/aur.txt.
#
# Run as your normal user (NOT root), after the first boot and after
# dotfiles.sh. makepkg refuses to run as root, which is the main reason none of
# this happens during the pacstrap install.
#
#   cd /root/airnix/arch && ./install/aur.sh [host]
#
# host is macbook-air or xps-8300; with no argument, the current hostname is
# used. Packages are filtered by the host comments in packages/aur.txt, so the
# Air does not build an NVIDIA driver and the XPS does not build mbpfan.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "run this as your normal user, not root (makepkg refuses to run as root)" >&2
  exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$HERE/../packages/aur.txt"
HOST="${1:-$(hostname)}"

case "$HOST" in
  macbook-air) SKIP='^nvidia-580xx' ;;
  xps-8300)    SKIP='^mbpfan$' ;;
  *) echo "unknown host '$HOST' (expected macbook-air or xps-8300)" >&2; exit 1 ;;
esac

PKGS="$(grep -vE '^\s*(#|$)' "$LIST" | grep -vE "$SKIP" || true)"
if [ -z "$PKGS" ]; then
  echo "nothing to install for $HOST"
  exit 0
fi

# paru is itself an AUR package, so bootstrap it from a plain clone once.
# Built from source (the -bin package has been flagged out of date); it needs
# rust, which base.txt already installs.
if ! command -v paru >/dev/null; then
  echo "==> bootstrapping paru"
  sudo pacman -S --needed --noconfirm base-devel git
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

echo "==> installing for $HOST:"
echo "$PKGS" | sed 's/^/    /'
# shellcheck disable=SC2086
paru -S --needed $PKGS

if [ "$HOST" = "xps-8300" ]; then
  cat <<'NOTE'

==> NVIDIA note
    nvidia-580xx-dkms replaces the repo driver. If nvidia-open or nvidia-utils
    got pulled in as a dependency, paru will have asked to remove them; that is
    correct. Reboot before expecting a working display, and rebuild this
    package after any kernel update (dkms does it automatically on a normal
    pacman -Syu, but check `dkms status` if X or niri fails to start).
NOTE
fi

if [ "$HOST" = "macbook-air" ]; then
  echo
  echo "==> enable fan control with:  sudo systemctl enable --now mbpfan.service"
fi
