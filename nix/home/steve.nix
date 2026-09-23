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

  # ---- niri + Noctalia ------------------------------------------------
  # System enablement is in modules/niri.nix; these are the per-user configs,
  # shared with the Arch side (arch/install/dotfiles.sh copies the same files).
  # Both land as read-only /nix/store symlinks: edit the files here and rebuild.
  # A running niri reloads config.kdl on save; Noctalia hot-reloads config.toml.
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
  xdg.configFile."noctalia/config.toml".source = ./noctalia/config.toml;

  programs.kitty.enable = true; # terminal niri launches (Mod+Return)

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

    # Wayland desktop
    noctalia # shell: bar, launcher, notifications, lock, wallpaper, clipboard
    wl-clipboard # wl-copy / wl-paste
    grim
    slurp # screenshots from the CLI (niri's Print bind has its own picker)
    brightnessctl # backlight from the CLI
    playerctl # media keys
    pavucontrol # audio mixer GUI
  ];

  # The HM release this config targets. Keep in step with system.stateVersion.
  home.stateVersion = "26.05";
}
