# Hyprland Wayland compositor, system-level enablement.
# Coexists with GNOME (modules/desktop.nix): pick the session at the login
# screen. The toolkit (bar, launcher, notifications, etc.) and the
# Hyprland config itself live in home/steve.nix so both machines share them.
{ config, lib, pkgs, ... }:

{
  # Enables the compositor, the portal wiring, and the required session bits.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # run X11 apps under Hyprland
  };

  # Let GDM (from modules/desktop.nix) offer the Hyprland session. GNOME stays
  # available as a fallback.

  # Sane Wayland defaults for Electron/Chromium apps and SDL.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps (incl. VS Code) on Wayland
  };

  # XDG portal for screen sharing / file pickers under Wayland.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
