# Shared system config used by every host (Air, XPS, ...).
# Per-machine hardware and drivers live in hosts/<name>/configuration.nix.
{ config, lib, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # ---- Nix daemon ------------------------------------------------------
  # Flakes + the new `nix` CLI on by default, so no per-command flags.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Deduplicate the store (helps on the old/small SSDs these machines have).
  nix.settings.auto-optimise-store = true;
  # Collect garbage weekly, keeping the last two weeks of generations so the
  # disk doesn't silently fill with old system builds.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Adopt the safer 26.11 default now (don't force-import an unclean root pool).
  # We don't use ZFS, but the option is in scope and warns until set explicitly.
  boot.zfs.forceImportRoot = false;

  # ---- Networking ------------------------------------------------------
  networking.networkmanager.enable = true;

  # ---- User account ----------------------------------------------------
  # Account creation lives here (shared); the user's *environment* (zsh,
  # git, dev tools) is managed by Home Manager in home/steve.nix.
  users.users.steve = {
    isNormalUser = true;
    description = "steve";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    shell = pkgs.zsh;
    # SSH public key for key-only login (the XPS has password auth disabled).
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKziwEzv9azGchDSu+WtP4EGApu2dMtBJvo3Pilgd5te"
    ];
    # No password set here. After first boot, log in as root (or sudo) and
    # run:  passwd steve
  };
  # zsh must be enabled at the system level for it to be a valid login shell.
  programs.zsh.enable = true;

  # ---- Containers ------------------------------------------------------
  # The module sets up the daemon, rootless networking, and docker-compat.
  # The bare `podman` package alone would not give a working setup.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # `docker` -> podman shim
  };

  # ---- Time / locale ---------------------------------------------------
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # ---- Firmware --------------------------------------------------------
  hardware.enableRedistributableFirmware = true;

  # ---- System-wide base packages --------------------------------------
  # User-facing dev tools live in home/steve.nix (Home Manager). These are
  # the bits that make sense available to every user, including root.
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
  ];

  # ---- Weekly SSD trim (harmless on spinning disks too) ----------------
  services.fstrim.enable = true;
}
