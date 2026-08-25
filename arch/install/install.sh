#!/usr/bin/env bash
# Arch install, run from the live ISO after you have partitioned/formatted/
# mounted the target at /mnt and have working network.
#
#   ./install.sh macbook-air
#   ./install.sh xps-8300
#
# What it does NOT do, on purpose:
#   - partition or format anything (you do that by hand; see the root README)
#   - create the ZFS pool on the XPS (disk layout is decided at install time)
# Both are destructive-by-nature steps that should not hide inside a script.
set -euo pipefail

HOST="${1:-}"
case "$HOST" in
  macbook-air|xps-8300) ;;
  *) echo "usage: $0 <macbook-air|xps-8300>" >&2; exit 1 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGDIR="$HERE/../packages"
USERNAME="steve"

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2; exit 1
fi
if ! mountpoint -q /mnt; then
  echo "/mnt is not mounted: partition/format/mount the target disk first" >&2
  exit 1
fi

# Strip comments and blanks so the lists stay readable but pacstrap-friendly.
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

echo "==> installing base system for $HOST"
PKGS="$(pkglist "$PKGDIR/base.txt"; pkglist "$PKGDIR/niri.txt"; pkglist "$PKGDIR/$HOST.txt")"
# shellcheck disable=SC2086
pacstrap -K /mnt $PKGS

echo "==> generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "==> copying repo into the new system at /root/airnix"
# Copy the CONTENTS of the repo into /root/airnix (note the trailing /. on the
# source), so the result is /root/airnix/arch, not /root/airnix/<repo>/arch.
# Excluded: .git and any build artifacts, which are large and useless here.
mkdir -p /mnt/root/airnix
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
if command -v rsync >/dev/null; then
  rsync -a --exclude '.git' --exclude '*.iso' --exclude 'result' \
        --exclude 'arch/iso/work' --exclude 'arch/iso/out' \
        --exclude 'arch/iso/profile' \
        "$REPO_ROOT/" /mnt/root/airnix/
else
  cp -r "$REPO_ROOT/." /mnt/root/airnix/
  rm -rf /mnt/root/airnix/.git
fi

echo "==> configuring inside chroot"
cp "$HERE/chroot-setup.sh" /mnt/tmp/chroot-setup.sh
chmod +x /mnt/tmp/chroot-setup.sh
arch-chroot /mnt /tmp/chroot-setup.sh "$HOST" "$USERNAME"
rm -f /mnt/tmp/chroot-setup.sh

cat <<EOF

==> base install done.

Remaining, by hand:
  1. Set passwords:      arch-chroot /mnt passwd
                         arch-chroot /mnt passwd $USERNAME
  2. Reboot, remove USB.
  3. Install dotfiles:   cd /root/airnix/arch && ./install/dotfiles.sh
$( [ "$HOST" = xps-8300 ] && echo "  4. Create the ZFS data pool (see root README, 'XPS: ZFS data pool')." )
$( [ "$HOST" = macbook-air ] && echo "  4. VERIFY you booted linux-lts, then check Wi-Fi: nmcli device wifi list" )
EOF
