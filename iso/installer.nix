# Installer ISO: a live USB tuned for the MacBook Air (BCM4360 + proprietary
# "wl" driver). This is the combination that actually got the Air online:
# NetworkManager + wl + a FULL blacklist of the open Broadcom stack (bcma etc.)
# so nothing competes with wl for the card.
#
# Tradeoff: blacklisting bcma/brcmsmac/brcmfmac means the XPS's BCM4313 (which
# needs brcmsmac) will NOT get Wi-Fi from this ISO. The XPS has Ethernet, so
# install it wired (or build a separate XPS-tuned ISO later). The Air's working
# install is the priority here.
#
# The whole flake rides along inside the image under /etc/nixos-install/nixusb,
# so install works with no network (see the README).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Text-mode minimal installer. Most reliable on Apple EFI; the graphical
    # (Calamares) ISO can misbehave there.
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # ---- Wi-Fi drivers for both cards ------------------------------------
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.36"
  ];
  # Air (BCM4360): proprietary wl. Blacklist the open Broadcom stack so it can't
  # fight wl for the card: bcma in particular grabs the 4360 first and leaves the
  # device half-broken (mislabeled eth0, cfg80211 errors). Blacklisting bcma was
  # what made wl cleanly own the card and get an IP. This DOES disable the XPS's
  # brcmsmac on this same ISO, accepted: the Air's working install comes first.
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.kernelModules = [ "wl" "applesmc" ];
  boot.blacklistedKernelModules = [ "b43" "bcma" "brcmsmac" "brcmfmac" ];

  hardware.enableRedistributableFirmware = true; # brcmsmac firmware for the 4313

  # The minimal ISO pulls in ZFS support; adopt the safer 26.11 default and
  # silence the warning (we don't install onto ZFS, but the option is in scope).
  boot.zfs.forceImportRoot = false;

  # ---- Live-environment networking: NetworkManager ---------------------
  # This is the setup that actually got the Air online (with bcma blacklisted
  # above so wl owns the card). Use nmtui to join Wi-Fi. The minimal ISO defaults
  # to plain wpa_supplicant, so force that off to avoid a mutually-exclusive
  # assertion with NetworkManager.
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  # Tools available the moment the live system boots.
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    wget
    curl
    htop
    tmux
    parted
    gptfdisk # partitioning
    pciutils
    usbutils # lspci / lsusb for sanity-checking hardware
    file
    tree
    rsync

    # Wireless diagnostics (the minimal ISO ships none of these).
    iw # iw dev / iw scan
    wirelesstools # iwconfig / iwlist
    # (rfkill comes from util-linux in the base system, no package needed)

    wpa_supplicant
    dhcpcd

    # wifi-connect: the sequence that actually gets the Air's BCM4360 online.
    # NetworkManager/iwd/nmtui don't work on this wl card (broken cfg80211);
    # plain wpa_supplicant + dhcpcd does, but ONLY from a clean device state
    # (stale wpa_supplicant/NetworkManager holding the card makes it fail).
    # This kills competitors, resets the link, associates, and gets a DHCP lease.
    # Usage:  wifi-connect "SSID" "PASSWORD"  [interface]   (iface defaults wlp3s0)
    (writeShellScriptBin "wifi-connect" ''
      set -e
      ssid="''${1:-}"; pass="''${2:-}"; iface="''${3:-wlp3s0}"
      if [ -z "$ssid" ] || [ -z "$pass" ]; then
        echo 'usage: wifi-connect "SSID" "PASSWORD" [interface]' >&2
        echo "(interface defaults to wlp3s0; check with: ip link)" >&2
        exit 1
      fi
      echo "==> clearing anything holding $iface"
      pkill wpa_supplicant 2>/dev/null || true
      systemctl stop NetworkManager 2>/dev/null || true
      systemctl stop iwd 2>/dev/null || true
      echo "==> resetting $iface"
      rfkill unblock all || true
      ip link set "$iface" down || true
      ip link set "$iface" up
      echo "==> associating with $ssid"
      wpa_passphrase "$ssid" "$pass" > /tmp/wpa.conf
      wpa_supplicant -B -i "$iface" -c /tmp/wpa.conf
      sleep 6
      if ! iw dev "$iface" link | grep -qi connected; then
        echo "!! not associated. Check the password, or run foreground to see why:" >&2
        echo "   sudo wpa_supplicant -i $iface -c /tmp/wpa.conf" >&2
        exit 1
      fi
      echo "==> associated; requesting DHCP lease"
      dhcpcd "$iface" || true
      sleep 3
      ip -4 addr show "$iface" | grep -q 'inet ' \
        && echo "==> online. test: ping nixos.org" \
        || echo "!! no IP via DHCP; set one manually (ip addr add ... ; ip route add default via ...)"
    '')

    # nixusb-stage: create /mnt/etc, copy the baked-in flake to /mnt/etc/nixos,
    # and make it writable (the ISO copy is read-only, which blocks hwconfig).
    # Run AFTER partition/format/mount, BEFORE nixusb-hwconfig. Usage: nixusb-stage
    (writeShellScriptBin "nixusb-stage" ''
      set -e
      src=/iso/etc/nixos-install/nixusb
      [ -d "$src" ] || src=/etc/nixos-install/nixusb   # fallback path
      if [ ! -d "$src" ]; then
        echo "can't find the baked-in flake (looked in /iso/etc/... and /etc/...)" >&2
        exit 1
      fi
      if ! mountpoint -q /mnt; then
        echo "/mnt is not mounted: partition/format/mount the target disk first" >&2
        exit 1
      fi
      echo "==> staging $src -> /mnt/etc/nixos"
      mkdir -p /mnt/etc
      cp -r "$src" /mnt/etc/nixos
      chmod -R u+w /mnt/etc/nixos
      echo "==> done. Next: nixusb-hwconfig macbook-air  (or xps-8300)"
    '')

    # Generate this machine's hardware-configuration.nix straight into the
    # baked-in flake's host dir. Usage:  nixusb-hwconfig macbook-air
    # (or xps-8300). Uses --show-hardware-config so it writes ONLY the hardware
    # file (filesystems included) and never a stray configuration.nix.
    (writeShellScriptBin "nixusb-hwconfig" ''
      set -e
      host="''${1:-}"
      flake="''${2:-/mnt/etc/nixos}"
      case "$host" in
        macbook-air|xps-8300) ;;
        *) echo "usage: nixusb-hwconfig <macbook-air|xps-8300> [flake-dir]" >&2
           echo "(flake-dir defaults to /mnt/etc/nixos)" >&2
           exit 1 ;;
      esac
      dest="$flake/hosts/$host/hardware-configuration.nix"
      if [ ! -d "$flake/hosts/$host" ]; then
        echo "no $flake/hosts/$host: stage the flake first with:  nixusb-stage" >&2
        exit 1
      fi
      echo "==> writing $dest"
      nixos-generate-config --root /mnt --show-hardware-config > "$dest"
      echo "==> done. Install with:"
      echo "  nixos-install --flake $flake#$host"
    '')
  ];

  # Bake the WHOLE flake into the ISO at /etc/nixos-install/nixusb. Both host
  # configs import shared modules and home/steve.nix, so a single file is
  # useless on its own; the entire tree has to ride along. This also means you
  # can install with NO network:
  #   nixos-install --flake /etc/nixos-install/nixusb#macbook-air
  # (after dropping the generated hardware-configuration.nix into hosts/<name>/).
  #
  # The filter keeps build artifacts out of the copy: a stray result symlink or
  # a 1.4 GB *.iso in the repo must NOT get embedded into the new ISO.
  isoImage.contents = [
    {
      source = lib.cleanSourceWith {
        src = ../.;
        filter = path: type:
          let base = baseNameOf path;
          in !(lib.hasSuffix ".iso" base
                || base == "result"
                || base == ".git");
      };
      target = "/etc/nixos-install/nixusb";
    }
  ];

  # nixpkgs 26.05 renamed isoImage.isoName -> image.fileName.
  image.fileName = lib.mkForce "nixusb-installer.iso";
}
