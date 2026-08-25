{
  description = "Multi-host NixOS flake: MacBook Air (Intel) + Dell XPS 8300, plus the Air installer ISO";

  inputs = {
    # NixOS 26.05 "Yarara" stable. Bump this string to move channels.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home Manager must track the SAME release as nixpkgs.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, ... }:
    let
      system = "x86_64-linux";

      # Home Manager wired as a NixOS module: steve's home is built by the same
      # `nixos-rebuild switch` that builds the system. Shared by every host.
      homeManagerModule = {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.steve = import ./home/steve.nix;
      };

      # Modules every host shares.
      commonModules = [
        ./modules/common.nix
        ./modules/desktop.nix
        ./modules/hyprland.nix
        ./modules/steam.nix
        home-manager.nixosModules.home-manager
        homeManagerModule
      ];
    in
    {
      nixosConfigurations = {
        # ---- MacBook Air (Intel) -------------------------------------
        macbook-air = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-pc-ssd
            ./hosts/macbook-air/configuration.nix
          ];
        };

        # ---- Dell XPS 8300 (NVIDIA GTX 1060) -------------------------
        xps-8300 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-pc-ssd
            ./hosts/xps-8300/configuration.nix
          ];
        };

        # ---- Installer ISO (Air + XPS) -------------------------------
        # Standalone: it deliberately does NOT pull the shared modules or
        # Home Manager, it's just a minimal live USB with both Wi-Fi drivers.
        installer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./iso/installer.nix ];
        };
      };
    };
}
