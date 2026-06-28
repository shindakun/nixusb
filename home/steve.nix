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

  # ---- Default browser: Firefox ----------------------------------------
  # GNOME Web (Epiphany) breaks OAuth redirect flows (e.g. claude /login fails
  # with "request not allowed"). Firefox works, so make it the default for
  # http/https/html, which is what `xdg-open` (and claude /login) use.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
  # GNOME pre-creates ~/.config/mimeapps.list, which collides with the above and
  # makes home-manager activation fail ("file is in the way"). Let HM overwrite it.
  xdg.configFile."mimeapps.list".force = true;

  # ---- Hyprland (Wayland compositor) ----------------------------------
  # System enablement is in modules/hyprland.nix; this is the per-user config.
  # A starter setup: kitty terminal, wofi launcher, waybar, mako notifications.
  wayland.windowManager.hyprland = {
    enable = true;
    # Home Manager flips the config format to Lua when home.stateVersion >= 26.05.
    # The Lua backend is buggy (mangles our settings into broken `hl.exec-once(...)`
    # etc., "syntax error near '-'"). Force the classic hyprlang `.conf` format,
    # which is what these `settings` are written for.
    configType = "hyprlang";
    settings = {
      exec-once = [
        "waybar"
        "mako"
        "hyprpaper"
        # Clipboard: keep a persistent clipboard + history so copy/paste works
        # between apps (Wayland has no clipboard daemon by default).
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      monitor = ",preferred,auto,1"; # autodetect; tune per-display later

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
      };

      bind = [
        "SUPER, Return, exec, kitty"
        "SUPER, D, exec, wofi --show drun"
        "SUPER, Q, killactive"
        "SUPER, M, exit"
        "SUPER, E, exec, nautilus"
        "SUPER, V, togglefloating"
        "SUPER, F, fullscreen"
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        # Screenshot region to clipboard. Wrapped in `bash -c` so the shell
        # handles the pipe/$()/dash, not Hyprland's bind parser (which errors
        # on the bare `-`).
        ", Print, exec, bash -c 'grim -g \"$(slurp)\" - | wl-copy'"
      ];

      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
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
