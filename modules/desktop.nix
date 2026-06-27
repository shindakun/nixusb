# Shared desktop config: GNOME, audio, fonts. Imported by hosts that want a
# graphical environment. Swap the desktop here once and both machines follow.
{ config, lib, pkgs, ... }:

{
  # ---- Desktop: GNOME --------------------------------------------------
  # To switch: KDE -> services.desktopManager.plasma6 + displayManager.sddm;
  # Xfce -> services.xserver.desktopManager.xfce + displayManager.lightdm.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb.layout = "us";

  # Drop GNOME Web (Epiphany): it breaks OAuth flows (e.g. claude /login). Use
  # Firefox instead (installed in home/steve.nix, set as default browser there).
  environment.gnome.excludePackages = [ pkgs.epiphany ];

  # ---- Audio (PipeWire) ------------------------------------------------
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ---- Fonts -----------------------------------------------------------
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
    libertine # Linux Libertine fonts
  ];
}
