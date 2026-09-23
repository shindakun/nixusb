# niri Wayland compositor + the services Noctalia's widgets talk to.
# Coexists with GNOME (modules/desktop.nix): pick "niri" at the GDM login
# screen. The niri config and the Noctalia shell config live in home/ so both
# machines share them.
{ config, lib, pkgs, ... }:

{
  # nixpkgs module: installs niri, registers the GDM session, wires the
  # gnome/gtk portals, and enables gnome-keyring.
  programs.niri.enable = true;

  # niri finds xwayland-satellite on PATH and starts it when an X11 client
  # connects (niri >= 25.08); nothing else is needed for X11 apps.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # Electron apps (incl. VS Code) on Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Noctalia's battery and bluetooth widgets read these (NetworkManager is
  # already on in modules/common.nix).
  services.upower.enable = true;
  hardware.bluetooth.enable = true;
}
