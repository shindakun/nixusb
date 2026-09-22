# Niri scrollable-tiling Wayland compositor, system-level enablement.
# Coexists with GNOME (modules/desktop.nix) and Hyprland (modules/hyprland.nix):
# pick the session at the login screen. The per-user config (keybinds, autostart
# noctalia-shell, etc.) lives in home/steve.nix so both machines share it.
{ config, lib, pkgs, ... }:

{
  # Installs niri, registers the Wayland session with GDM, and wires
  # session variables / dbus activation for a working compositor.
  programs.niri.enable = true;

  # Portals are already declared in modules/hyprland.nix (gtk portal). Niri
  # works with the same set, so nothing extra to add here — module merging
  # takes care of it. If Hyprland is removed later, re-declare xdg.portal
  # here so screen sharing / file pickers keep working under Niri.
}
