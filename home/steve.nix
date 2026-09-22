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
  # ~/.gitconfig is a read-only symlink into /nix/store (Home Manager manages
  # it), so `git config --global` fails. Put global git settings HERE instead.
  programs.git = {
    enable = true;
    lfs.enable = true;
    # Set your identity here once and both machines share it.
    settings.user.name = "steve";
    settings.user.email = "shindakun@users.noreply.github.com";
    # Always talk to GitHub over SSH, even when a remote is an https URL.
    # (Pushing still needs an SSH key registered on your GitHub account.)
    settings.url."git@github.com:".insteadOf = "https://github.com/";
  };

  # ---- delta (syntax-highlighted diffs; wires itself as git's pager) --
  # HM hoisted this out of `programs.git.delta` — explicit git integration.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # ---- bat (syntax-highlighted `cat`) ---------------------------------
  programs.bat.enable = true;

  # ---- micro (terminal text editor) -----------------------------------
  # HM writes settings to ~/.config/micro/settings.json.
  # Options: https://github.com/zyedidia/micro/blob/master/runtime/help/options.md
  programs.micro = {
    enable = true;
    settings = {
      colorscheme = "simple";
      tabsize = 2;
      tabstospaces = true;
    };
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
  xdg.configFile."hypr/hyprland.conf".force = true;
  xdg.configFile."niri/config.kdl".force = true;

  # Suppress the system-wide ibus autostart. nixpkgs ships
  # /etc/xdg/autostart/ibus-daemon.desktop (pulled in transitively via GNOME),
  # which systemd's xdg-autostart generator turns into a running user unit even
  # under Niri. A user-level override with Hidden=true takes precedence and the
  # generator skips it. Remove this stanza if you actually want an IME.
  xdg.configFile."autostart/ibus-daemon.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=IBus
    Hidden=true
  '';

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
    # Variables ($mod etc.) go in `variables`, which Home Manager emits FIRST,
    # before any bind that references them. Putting them in `settings` could
    # emit them after the binds, so Hyprland parses `$mod` before it's defined
    # ("<name> expected near '$'"). SUPER is inlined in binds to be safe.
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

  # ---- Niri (scrollable-tiling Wayland compositor) --------------------
  # System enablement is in modules/niri.nix. This writes the KDL config
  # directly; there's no built-in HM module for niri in nixpkgs 26.05.
  # Autostarts noctalia-shell (Quickshell-based bar/launcher/notifications),
  # so waybar/mako/wofi are NOT launched under this session.
  xdg.configFile."niri/config.kdl".text = ''
    // Managed by home-manager (home/steve.nix). Edit there, not here.

    spawn-at-startup "noctalia-shell"

    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
    }

    layout {
        gaps 12
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        focus-ring {
            width 2
        }
    }

    prefer-no-csd

    hotkey-overlay {
        skip-at-startup
    }

    binds {
        Mod+Return { spawn "kitty"; }
        Mod+D      { spawn "wofi" "--show" "drun"; }
        Mod+Q      { close-window; }
        Mod+Shift+M { quit; }
        Mod+E      { spawn "nautilus"; }
        Mod+V      { toggle-window-floating; }
        Mod+F      { fullscreen-window; }

        Mod+Left   { focus-column-left; }
        Mod+Right  { focus-column-right; }
        Mod+Up     { focus-window-up; }
        Mod+Down   { focus-window-down; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }

        Print { spawn "sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }
    }
  '';

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
    eza

    # herdr-file-viewer optional renderers (bat + delta wired via programs.*)
    glow

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
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

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

    # Niri toolkit (noctalia = Quickshell-based bar/launcher/notifications)
    noctalia-shell
    quickshell
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  # The HM release this config targets. Keep in step with system.stateVersion.
  home.stateVersion = "26.05";
}
