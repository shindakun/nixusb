# Dell XPS 8300 (2011 Sandy Bridge desktop, NVIDIA GTX 1060 Pascal GPU).
# Shared bits come from modules/ and home/ via flake.nix. This file is ONLY
# the XPS-specific hardware. Networking is a Dell DW1501 (BCM4313) Wi-Fi card
# (open brcmsmac driver); on the installer ISO run `use-brcmsmac` to select it.
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "xps-8300";

  # ---- Boot ------------------------------------------------------------
  # The XPS 8300 shipped with legacy BIOS but its firmware can do UEFI. If you
  # installed in UEFI mode, systemd-boot below is correct. If you used legacy
  # BIOS/MBR, comment these two out and set:
  #   boot.loader.grub.enable = true;
  #   boot.loader.grub.device = "/dev/sda";   # the disk you installed to
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---- CPU -------------------------------------------------------------
  hardware.cpu.intel.updateMicrocode = true;

  # ---- Wi-Fi: Dell DW1501 (Broadcom BCM4313) ---------------------------
  # No factory Wi-Fi on the XPS 8300; this is the added DW1501 mini-PCIe card.
  # The BCM4313 uses the open in-kernel brcmsmac driver plus redistributable
  # firmware (enabled in modules/common.nix). b43 is blacklisted because it
  # would wrongly try to claim this chip.
  boot.kernelModules = [ "brcmsmac" ];
  boot.blacklistedKernelModules = [ "b43" "wl" ];

  # ---- NVIDIA GTX 1060 (Pascal) ----------------------------------------
  # The GTX 1060 is supported by the CURRENT proprietary driver (not a legacy
  # branch, not nouveau). allowUnfree is already set in modules/common.nix.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true; # required for Wayland (Hyprland)
    open = false; # GTX 1060 predates the open module; use proprietary
    nvidiaSettings = true; # the nvidia-settings GUI
    powerManagement.enable = false; # desktop, no suspend power tricks needed
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ---- Incus (system containers + VMs) ---------------------------------
  # Runs alongside Podman (from modules/common.nix), not instead of it:
  # Podman for app/OCI containers, Incus for full system containers and VMs.
  virtualisation.incus.enable = true;
  # Incus on NixOS requires the nftables firewall backend (asserts otherwise).
  networking.nftables.enable = true;
  # Let steve drive incus without sudo.
  users.users.steve.extraGroups = [ "incus-admin" ];
  # Incus needs its bridge allowed through the firewall for instance networking.
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  # ---- SSH -------------------------------------------------------------
  # The XPS is a desktop you may want to reach headless from the Air. Keep it
  # key-only (no password auth) for safety on the LAN.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # ---- ZFS data pool ---------------------------------------------------
  # The XPS has several SSDs. Root stays on ext4 (simple, no kernel-module risk
  # at boot); the extra SSDs form a ZFS DATA pool, NOT the root. So this enables
  # ZFS support but does not put the OS on it.
  #
  # The pool itself is created BY HAND once on the real hardware (the disk
  # sizes/layout aren't known yet), e.g.:
  #   zpool create -o ashift=12 -O compression=zstd -O mountpoint=/data \
  #     tank mirror /dev/disk/by-id/<ssd-a> /dev/disk/by-id/<ssd-b>
  # ZFS then imports it automatically on boot (hostId below makes that safe).
  # ZFS is an out-of-tree module: it lags the newest kernels. The channel's
  # default kernel is kept ZFS-compatible, so do NOT switch boot.kernelPackages
  # to linuxPackages_latest here without checking ZFS supports it, or boot breaks.
  boot.supportedFilesystems = [ "zfs" ];
  # ZFS REQUIRES a unique 8-hex-char hostId; it refuses to import a pool without
  # one. Generated for this machine; do not reuse it on another host.
  networking.hostId = "72a21b30";
  services.zfs = {
    autoScrub.enable = true;             # monthly integrity scrub (repairs on redundant pools)
    trim.enable = true;                  # periodic SSD trim of the pool
    autoSnapshot.enable = true;          # rolling snapshots (frequent/hourly/daily/...)
  };

  system.stateVersion = "26.05";
}
