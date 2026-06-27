# Installer ISO: a live USB that can join Wi-Fi on both machines (Air + XPS).
#
#   - MacBook Air: BCM4360, needs the proprietary "wl" driver (broadcom_sta).
#   - Dell XPS 8300 (DW1501): BCM4313, uses the open in-kernel "brcmsmac".
#
# These coexist: `wl` binds only the 4360 (14e4:43a0) and `brcmsmac` binds only
# the 4313 (14e4:4727), each by its own PCI id. So we load `wl` for the Air but
# do NOT blacklist the open Broadcom stack the XPS needs. We still blacklist
# `b43`, which would otherwise wrongly try to claim the 4313 (brcmsmac is the
# right driver for it).
#
# Both machines' installed configs ride along inside the image under
# /etc/nixos-install/ so you don't transfer them from another machine. The
# easiest install is flake-based (see the README).
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
  # Air (BCM4360): proprietary wl. XPS (BCM4313): open brcmsmac, which is
  # in-kernel and loads on demand, so it needs no extraModulePackages.
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.kernelModules = [ "wl" "applesmc" ];
  # Only blacklist b43 (it fights brcmsmac over the 4313). Leave bcma/brcmsmac/
  # brcmfmac available so the XPS card binds.
  boot.blacklistedKernelModules = [ "b43" ];

  hardware.enableRedistributableFirmware = true; # brcmsmac firmware for the 4313

  # NetworkManager (nmtui) in the live environment. The minimal ISO defaults
  # to wpa_supplicant, so force that off to avoid a mutually-exclusive assertion.
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
  ];

  # Bake BOTH machines' installed-system configs into the ISO. With the
  # flake-based install you usually won't need these (you clone/copy the whole
  # flake instead), but they are handy as a reference on the live system.
  isoImage.contents = [
    {
      source = ../hosts/macbook-air/configuration.nix;
      target = "/etc/nixos-install/macbook-air.nix";
    }
    {
      source = ../hosts/xps-8300/configuration.nix;
      target = "/etc/nixos-install/xps-8300.nix";
    }
  ];

  # nixpkgs 26.05 renamed isoImage.isoName -> image.fileName.
  image.fileName = lib.mkForce "nixusb-installer.iso";
}
