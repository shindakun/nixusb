# Steam, shared by both hosts. It's a system-level program module (pulls 32-bit
# graphics libs and opens the ports Steam needs); it is NOT a Home Manager app.
#
# Reality check: the XPS 8300's GTX 1060 is the real gaming GPU. The MacBook
# Air's integrated Intel graphics will launch Steam and run light/older titles,
# but don't expect much from it.
{ config, lib, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Steam Remote Play
    dedicatedServer.openFirewall = false; # flip on only if you host servers
  };
  # Steam needs the 32-bit graphics stack.
  hardware.graphics.enable32Bit = true;
}
