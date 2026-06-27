# Home Manager: steve's user environment, shared across every host.
# Imported via the home-manager NixOS module in flake.nix, so it is applied
# by the same `nixos-rebuild switch` that builds the system.
{ config, lib, pkgs, ... }:

{
  home.username = "steve";
  home.homeDirectory = "/home/steve";

  # ---- Shell: zsh + oh-my-zsh -----------------------------------------
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      # HM spelling (system module uses ohMyZsh)
      enable = true;
      theme = "robbyrussell"; # OMZ default; change to taste
      plugins = [ "git" "direnv" "fzf" "sudo" ];
    };
  };

  # ---- direnv (with nix-direnv) ---------------------------------------
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ---- fzf shell integration ------------------------------------------
  programs.fzf.enable = true;

  # ---- zoxide (smarter cd; hooks into zsh) ----------------------------
  programs.zoxide.enable = true;

  # ---- git -------------------------------------------------------------
  programs.git = {
    enable = true;
    lfs.enable = true;
    # Set your identity here once and both machines share it.
    settings.user.name = "steve";
    settings.user.email = "shindakun@users.noreply.github.com";
  };

  # ---- gh (GitHub CLI) -------------------------------------------------
  programs.gh.enable = true;

  # ---- Hyprland (Wayland compositor) ----------------------------------
  # System enablement is in modules/hyprland.nix; this is the per-user config.
  # A starter setup: kitty terminal, wofi launcher, waybar, mako notifications.
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      "$term" = "kitty";
      "$menu" = "wofi --show drun";

      exec-once = [
        "waybar"
        "mako"
        "hyprpaper"
      ];

      monitor = ",preferred,auto,1"; # autodetect; tune per-display later

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
      };

      bind = [
        "$mod, Return, exec, $term"
        "$mod, D, exec, $menu"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, nautilus"
        "$mod, V, togglefloating"
        "$mod, F, fullscreen"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  programs.kitty.enable = true; # terminal Hyprland launches

  # ---- User packages (the dev environment, shared by all hosts) -------
  home.packages = with pkgs; [
    # terminal / CLI
    tmux
    httpie
    jq
    yq-go # YAML/JSON processor
    htop
    btop
    unzip
    p7zip # 7z and more archive formats
    fastfetch # system info
    tealdeer # tldr: quick command examples
    lazygit # TUI git

    # nicer CLI replacements
    ripgrep
    fd
    bat
    eza

    # browsers
    firefox
    chromium

    # editors
    vscode
    zed-editor

    # AI / node
    claude-code
    nodejs

    # Nix tooling
    nil
    nixpkgs-fmt

    # devtools: compilers, build systems, languages
    cmake
    gcc
    go
    gnumake
    pkg-config

    # media
    mpv # video player
    imv # Wayland image viewer

    # Hyprland toolkit
    waybar # status bar
    wofi # app launcher
    mako # notifications
    hyprpaper # wallpaper
    hyprlock # screen locker
    hypridle # idle daemon (triggers hyprlock)
    wlogout # power menu
    grim
    slurp # screenshots (region select)
    swappy # annotate screenshots
    cliphist # clipboard history
    wl-clipboard # wl-copy / wl-paste
    networkmanagerapplet # nm-applet tray (Wi-Fi under Hyprland)
    brightnessctl # backlight keys
    pavucontrol # audio mixer GUI
  ];

  # The HM release this config targets. Keep in step with system.stateVersion.
  home.stateVersion = "26.05";
}
