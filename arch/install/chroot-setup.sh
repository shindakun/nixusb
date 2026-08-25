#!/usr/bin/env bash
# Runs INSIDE arch-chroot /mnt. Called by install.sh; not meant to be run by hand.
# Usage: chroot-setup.sh <host> <username>
set -euo pipefail

HOST="${1:?host required}"
USERNAME="${2:?username required}"

echo "==> locale / time / hostname"
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
echo "$HOST" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST.localdomain $HOST
EOF

echo "==> user: $USERNAME"
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -G wheel,video,audio,input,storage -s /usr/bin/zsh "$USERNAME"
fi
# wheel gets sudo (password required).
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

echo "==> host-specific configuration"
case "$HOST" in
  macbook-air)
    # The whole Wi-Fi story in one place. broadcom-wl's cfg80211 breaks on
    # current mainline kernels, which is what makes NetworkManager unusable.
    # linux-lts is the known-good pairing, so it is the DEFAULT boot entry and
    # plain `linux` is kept only as a fallback.
    #
    # Blacklist the open Broadcom stack so `wl` owns the BCM4360 cleanly. If
    # bcma grabs it first the interface comes up mislabeled (eth0) and nothing
    # works. This mirrors the NixOS blacklist exactly.
    cat > /etc/modprobe.d/broadcom-wl.conf <<'EOF'
blacklist b43
blacklist bcma
blacklist brcmsmac
blacklist brcmfmac
EOF
    # applesmc drives fans/temps/backlight on Apple hardware.
    echo applesmc > /etc/modules-load.d/applesmc.conf

    systemctl enable tlp.service 2>/dev/null || true
    systemctl enable thermald.service 2>/dev/null || true
    systemctl enable mbpfan.service 2>/dev/null || true
    ;;

  xps-8300)
    # BCM4313 uses in-kernel brcmsmac; b43 and wl would both wrongly claim it.
    cat > /etc/modprobe.d/brcmsmac.conf <<'EOF'
blacklist b43
blacklist wl
EOF
    # NVIDIA: modesetting is required for Wayland (niri).
    cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF
    echo -e 'nvidia\nnvidia_modeset\nnvidia_uvm\nnvidia_drm' > /etc/modules-load.d/nvidia.conf

    # Incus needs nftables, not iptables (same constraint as the NixOS config).
    systemctl enable nftables.service 2>/dev/null || true
    systemctl enable incus.service 2>/dev/null || true
    systemctl enable sshd.service 2>/dev/null || true
    systemctl enable prometheus.service 2>/dev/null || true
    systemctl enable prometheus-node-exporter.service 2>/dev/null || true
    systemctl enable grafana.service 2>/dev/null || true
    systemctl enable jellyfin.service 2>/dev/null || true
    usermod -aG incus-admin "$USERNAME" 2>/dev/null || true
    ;;
esac

echo "==> initramfs"
mkinitcpio -P

echo "==> bootloader (systemd-boot, UEFI)"
# Both machines are installed in UEFI mode (Apple EFI on the Air; the XPS 8300
# firmware can do UEFI). For legacy BIOS on the XPS use GRUB instead.
bootctl install

ROOT_UUID="$(findmnt -no UUID /)"

# On the Air, linux-lts is the DEFAULT (see the Wi-Fi note above). On the XPS,
# plain linux is the default and lts is the fallback.
if [ "$HOST" = macbook-air ]; then
  DEFAULT_ENTRY="arch-lts.conf"
else
  DEFAULT_ENTRY="arch.conf"
fi

cat > /boot/loader/loader.conf <<EOF
default $DEFAULT_ENTRY
timeout 3
console-mode keep
editor no
EOF

mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
EOF
cat > /boot/loader/entries/arch-lts.conf <<EOF
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=UUID=$ROOT_UUID rw
EOF

echo "==> enabling shared services"
systemctl enable NetworkManager.service
systemctl enable greetd.service 2>/dev/null || true

echo "==> chroot setup complete (default boot entry: $DEFAULT_ENTRY)"
