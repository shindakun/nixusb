# Niri scrollable-tiling Wayland compositor, system-level enablement.
# Coexists with GNOME (modules/desktop.nix): pick the session at the login
# screen. The per-user config (keybinds, autostart noctalia-shell, etc.) lives
# in home/steve.nix so both machines share it.
{ config, lib, pkgs, ... }:

{
  # Installs niri, registers the Wayland session with GDM, and wires
  # session variables / dbus activation for a working compositor. The nixpkgs
  # module also sets up the gnome/gtk portals and gnome-keyring.
  programs.niri.enable = true;

  # Portals used to come from modules/hyprland.nix. That module is gone, so the
  # warning its comment carried is now handled: programs.niri sets xdg.portal
  # with the gnome + gtk backends, which is what screen sharing and file
  # pickers need here.

  # Niri has no built-in XWayland. It creates the X11 socket itself and starts
  # xwayland-satellite on demand when an X11 client connects (niri >= 25.08),
  # as long as the binary is on PATH.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # Electron apps (incl. VS Code) on Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Noctalia's battery and bluetooth widgets read these (NetworkManager is
  # already on in modules/common.nix).
  services.upower.enable = true;
  hardware.bluetooth.enable = true;
}
