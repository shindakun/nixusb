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

  # ---- niri (scrollable-tiling Wayland compositor) --------------------
  # System enablement is in modules/niri.nix. The config is a plain KDL file
  # shared with the Arch side (arch/install/dotfiles.sh copies the same one),
  # since nixpkgs 26.05 has no Home Manager module for niri.
  #
  # It lands as a read-only /nix/store symlink: edit nix/home/niri/config.kdl
  # and rebuild, never ~/.config/niri/config.kdl. A running niri reloads the
  # file on save.
  #
  # niri/shell.kdl is the one piece that differs per distro: this machine runs
  # Noctalia v4 (noctalia-shell, Quickshell-based), while Arch packages only
  # v5. config.kdl includes it, so the shared file stays identical on both.
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
  xdg.configFile."niri/shell.kdl".source = ./niri/shell-v4.kdl;

  programs.kitty.enable = true; # the terminal niri launches (Mod+Return)

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

    # AI
    claude-code

    # ---- language toolchains (kept in step with arch/packages/base.txt) ----
    # C / C++
    gcc
    cmake
    gnumake
    pkg-config

    # Go
    go

    # Rust
    rustc
    cargo
    clippy
    rustfmt

    # Node
    nodejs # ships npm
    pnpm

    # Python. uv handles envs, installs, and pinned tool runs; no pip needed.
    python3
    uv

    # ---- language servers, linters, formatters ----
    nil
    nixpkgs-fmt
    gopls
    rust-analyzer
    typescript-language-server
    ruff # python lint + format
    shellcheck
    shfmt

    # media
    mpv # video player
    imv # Wayland image viewer

    # ---- Wayland desktop ----
    # Noctalia v4 (Quickshell-based) is what runs on the Air today: bar,
    # launcher, notifications. nixpkgs also carries the native v5 as
    # `noctalia`, which is what Arch packages; the two are separate installs
    # with separate config formats, so this side stays on v4 until the Air is
    # deliberately moved.
    noctalia-shell
    quickshell

    wofi # launcher the niri config binds to Mod+D
    wl-clipboard # wl-copy / wl-paste
    grim
    slurp # screenshot region select (the Print bind pipes these to wl-copy)
    brightnessctl # backlight keys
    playerctl # media keys
    pavucontrol # audio mixer GUI
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  # The HM release this config targets. Keep in step with system.stateVersion.
  home.stateVersion = "26.05";
}
