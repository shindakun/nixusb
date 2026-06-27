# MacBook Air (older Intel, MacBookAir6,x / 7,x, BCM4360 Wi-Fi).
# Shared bits (nix, podman, user, desktop, fonts) come from modules/ and
# home/ via flake.nix. This file is ONLY the Air-specific hardware.
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "macbook-air";

  # ---- Boot (Apple EFI) ------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---- Wi-Fi: Broadcom "wl" driver (BCM4360, 2013-2017 Airs) -----------
  # broadcom_sta is flagged insecure in nixpkgs (CVE-2019-9501/9502) but is
  # the only driver for the BCM4360, so permit it explicitly. Bump this
  # string if a kernel rebuild changes the suffix (nix prints the new one).
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.36"
  ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.kernelModules = [ "wl" "applesmc" "kvm-intel" ];
  boot.blacklistedKernelModules = [ "b43" "bcma" "brcmsmac" "brcmfmac" ];

  # For a 2010-2012 Air (b43), use these instead of the broadcom block above:
  # boot.kernelModules = [ "b43" "applesmc" "kvm-intel" ];
  # boot.blacklistedKernelModules = [ "wl" ];
  # networking.enableB43Firmware = true;

  # ---- Apple hardware --------------------------------------------------
  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.enable = true;
  # FaceTime HD camera: 2013+ Airs. Fetches firmware at build time, so build
  # while online. Older 2010-2012 iSight works via uvcvideo with nothing here.
  hardware.facetimehd.enable = true;

  # ---- Trackpad --------------------------------------------------------
  services.libinput.enable = true;
  services.libinput.touchpad.tapping = true;
  services.libinput.touchpad.naturalScrolling = true;

  # ---- Power & thermals (old Airs run hot; this matters) ---------------
  services.thermald.enable = true;
  services.tlp.enable = true;
  # GNOME pulls in power-profiles-daemon, which conflicts with TLP. We want
  # TLP on this laptop, so turn ppd off.
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "schedutil";

  system.stateVersion = "26.05";
}
