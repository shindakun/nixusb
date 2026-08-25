#!/usr/bin/env bash
# Build the airnix Arch installer ISO with Broadcom wl baked in.
# MUST run on an Arch host (or an Arch container) with archiso installed.
#
#   sudo pacman -S archiso
#   sudo ./build.sh
#
# Output: ./out/airnix-arch-<date>.iso
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
PROFILE="$HERE/profile"
WORK="$HERE/work"
OUT="$HERE/out"

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (archiso needs it)" >&2; exit 1
fi
if ! command -v mkarchiso >/dev/null; then
  echo "mkarchiso not found. Install it:  pacman -S archiso" >&2; exit 1
fi
if [ ! -d /usr/share/archiso/configs/releng ]; then
  echo "archiso releng profile missing; is archiso installed correctly?" >&2; exit 1
fi

echo "==> building profile from releng"
rm -rf "$PROFILE" "$WORK"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

echo "==> adding packages"
# broadcom-wl-dkms needs dkms + headers for EVERY kernel in the ISO.
cat >> "$PROFILE/packages.x86_64" <<'EOF'

# --- airnix additions ---
linux-lts
linux-lts-headers
linux-headers
dkms
broadcom-wl-dkms
networkmanager
wpa_supplicant
dhcpcd
iw
wireless_tools
git
neovim
parted
gptfdisk
rsync
zsh
EOF

echo "==> baking the repo into the ISO at /root/airnix"
mkdir -p "$PROFILE/airootfs/root/airnix"
# Copy the repo but leave out build artifacts and git metadata.
rsync -a --exclude '.git' --exclude '*.iso' --exclude 'result' \
      --exclude 'arch/iso/work' --exclude 'arch/iso/out' \
      --exclude 'arch/iso/profile' \
      "$REPO/" "$PROFILE/airootfs/root/airnix/"

echo "==> installing live helper scripts"
mkdir -p "$PROFILE/airootfs/usr/local/bin"

# use-wl: select the proprietary wl driver (MacBook Air / BCM4360).
cat > "$PROFILE/airootfs/usr/local/bin/use-wl" <<'EOF'
#!/usr/bin/env bash
set -e
echo "==> switching to wl (MacBook Air / BCM4360)"
systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
modprobe -r brcmfmac brcmsmac bcma b43 wl 2>/dev/null || true
modprobe wl
sleep 2
echo "==> driver now bound:"
lspci -nnk -d 14e4: | grep -iE 'network|driver in use' || true
echo "==> next: try nmtui, or  wifi-connect \"SSID\" \"PASSWORD\""
EOF

# use-brcmsmac: select the open brcmsmac driver (XPS 8300 / BCM4313).
cat > "$PROFILE/airootfs/usr/local/bin/use-brcmsmac" <<'EOF'
#!/usr/bin/env bash
set -e
echo "==> switching to brcmsmac (XPS 8300 / BCM4313)"
systemctl stop wpa_supplicant 2>/dev/null || true
modprobe -r wl b43 2>/dev/null || true
modprobe brcmsmac
sleep 2
systemctl restart NetworkManager 2>/dev/null || true
echo "==> driver now bound:"
lspci -nnk -d 14e4: | grep -iE 'network|driver in use' || true
echo "==> next: try nmtui, or  wifi-connect \"SSID\" \"PASSWORD\""
EOF

cp "$REPO/arch/install/wifi-connect.sh" "$PROFILE/airootfs/usr/local/bin/wifi-connect"
chmod +x "$PROFILE/airootfs/usr/local/bin/"*

# Boot neutral: blacklist only b43 (it mis-claims the 4313). The two machines
# need opposite Broadcom setups, so pick at runtime with use-wl/use-brcmsmac.
mkdir -p "$PROFILE/airootfs/etc/modprobe.d"
echo 'blacklist b43' > "$PROFILE/airootfs/etc/modprobe.d/airnix-neutral.conf"

echo "==> running mkarchiso (this takes a while)"
mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

rm -rf "$WORK"
echo
echo "==> done. ISO is in $OUT/"
ls -lh "$OUT"/*.iso
