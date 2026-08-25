# Dell XPS 8300 (2011 Sandy Bridge desktop, NVIDIA GTX 1060 Pascal GPU).
# Shared bits come from modules/ and home/ via flake.nix. This file is ONLY
# the XPS-specific hardware. Networking is a Dell DW1501 (BCM4313) Wi-Fi card
# (open brcmsmac driver); on the installer ISO run `use-brcmsmac` to select it.
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "xps-8300";

  # ---- Boot ------------------------------------------------------------
  # The XPS 8300 shipped with legacy BIOS but its firmware can do UEFI. If you
  # installed in UEFI mode, systemd-boot below is correct. If you used legacy
  # BIOS/MBR, comment these two out and set:
  #   boot.loader.grub.enable = true;
  #   boot.loader.grub.device = "/dev/sda";   # the disk you installed to
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---- CPU -------------------------------------------------------------
  hardware.cpu.intel.updateMicrocode = true;

  # ---- Wi-Fi: Dell DW1501 (Broadcom BCM4313) ---------------------------
  # No factory Wi-Fi on the XPS 8300; this is the added DW1501 mini-PCIe card.
  # The BCM4313 uses the open in-kernel brcmsmac driver plus redistributable
  # firmware (enabled in modules/common.nix). b43 is blacklisted because it
  # would wrongly try to claim this chip.
  # kvm-intel is here too so Incus VMs (e.g. Home Assistant OS) work; see below.
  boot.kernelModules = [ "brcmsmac" "kvm-intel" ];
  boot.blacklistedKernelModules = [ "b43" "wl" ];

  # ---- NVIDIA GTX 1060 (Pascal) ----------------------------------------
  # The GTX 1060 is supported by the CURRENT proprietary driver (not a legacy
  # branch, not nouveau). allowUnfree is already set in modules/common.nix.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true; # required for Wayland (Hyprland)
    open = false; # GTX 1060 predates the open module; use proprietary
    nvidiaSettings = true; # the nvidia-settings GUI
    powerManagement.enable = false; # desktop, no suspend power tricks needed
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ---- Incus (system containers + VMs) ---------------------------------
  # Runs alongside Podman (from modules/common.nix), not instead of it:
  # Podman for app/OCI containers, Incus for full system containers and VMs.
  virtualisation.incus.enable = true;
  # Incus on NixOS requires the nftables firewall backend (asserts otherwise).
  networking.nftables.enable = true;
  # Let steve drive incus without sudo.
  users.users.steve.extraGroups = [ "incus-admin" ];
  # Incus needs its bridge allowed through the firewall for instance networking.
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  # Incus VMs (as opposed to system containers) need KVM. The Intel CPU provides
  # it; load the module so `incus launch --vm` works. This is what lets us run
  # Home Assistant OS (HAOS) as a full VM appliance, e.g.:
  #   incus init haos --empty --vm -c limits.cpu=2 -c limits.memory=4GiB
  #   incus config device add haos root disk pool=<pool> size=32GiB   # on ZFS pool
  #   # import the HAOS .qcow2 image, then start it.
  # For HA device discovery/mDNS you'll usually want the VM BRIDGED onto the LAN
  # (a macvlan/bridged Incus profile), not NATed behind incusbr0. That's a
  # runtime `incus profile`/`incus config device` choice, not declared here.
  # (kvm-intel is loaded in the Wi-Fi block's boot.kernelModules above.)

  # ---- SSH -------------------------------------------------------------
  # The XPS is a desktop you may want to reach headless from the Air. Keep it
  # key-only (no password auth) for safety on the LAN.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # ---- Monitoring: Prometheus + Grafana --------------------------------
  # node exporter (CPU/RAM/disk/temps) scraped by Prometheus; Grafana on :3000
  # to visualize. Reachable from the Air over the LAN (see firewall below).
  services.prometheus = {
    enable = true;
    exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      # defaults to :9100
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "localhost:9100" ]; }];
      }
      # Incus exposes metrics at https://localhost:8443/1.0/metrics, but the
      # scrape needs a client cert trusted by Incus, which only exists after you
      # set it up on the running box:
      #   incus config trust add-certificate <prometheus-client.crt> --type metrics
      # Uncomment and point tls_config at the generated cert/key once created:
      # {
      #   job_name = "incus";
      #   metrics_path = "/1.0/metrics";
      #   scheme = "https";
      #   static_configs = [{ targets = [ "localhost:8443" ]; }];
      #   tls_config = {
      #     ca_file = "/var/lib/incus/server.crt";
      #     cert_file = "/var/lib/prometheus/incus-metrics.crt";
      #     key_file = "/var/lib/prometheus/incus-metrics.key";
      #   };
      # }
    ];
  };
  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "0.0.0.0"; # reachable from the Air; drop to 127.0.0.1 for local-only
      http_port = 3000;
    };
    # Grafana 26.05 requires an explicit secret_key (encrypts secrets in its DB).
    # Do NOT hard-code it in this public repo: read it from a file created ONCE on
    # the box (not tracked by git):
    #   sudo install -d -o grafana -g grafana /var/lib/grafana
    #   openssl rand -hex 32 | sudo tee /var/lib/grafana/secret_key >/dev/null
    #   sudo chown grafana:grafana /var/lib/grafana/secret_key
    #   sudo chmod 600 /var/lib/grafana/secret_key
    settings.security.secret_key = "$__file{/var/lib/grafana/secret_key}";
  };
  # ---- Jellyfin (media server) -----------------------------------------
  # Native service (not a container): simplest on NixOS and GPU transcoding
  # works via the host NVIDIA driver, no passthrough. Web UI on :8096.
  # NVENC hardware transcoding: enable it in the Jellyfin web UI
  # (Dashboard -> Playback -> Hardware acceleration = NVENC). The nvidia driver
  # (services.xserver.videoDrivers = ["nvidia"], set above) provides it.
  # Media lives on the ZFS pool; the `jellyfin` service user needs read access
  # to wherever you put it (e.g. put media under a dir the jellyfin user can read,
  # or add jellyfin to a media group). That's a runtime step after the pool exists.
  services.jellyfin = {
    enable = true;
    openFirewall = true; # opens 8096/8920 (http/https) + DLNA discovery ports
  };

  # Open Grafana (3000) on the LAN. Prometheus (9090) and node exporter (9100)
  # stay local unless you also want to reach them directly. (Jellyfin's ports
  # are opened by services.jellyfin.openFirewall above.)
  networking.firewall.allowedTCPPorts = [ 3000 ];

  # ---- ZFS data pool ---------------------------------------------------
  # The XPS has several SSDs. Root stays on ext4 (simple, no kernel-module risk
  # at boot); the extra SSDs form a ZFS DATA pool, NOT the root. So this enables
  # ZFS support but does not put the OS on it.
  #
  # The pool itself is created BY HAND once on the real hardware (the disk
  # sizes/layout aren't known yet), e.g.:
  #   zpool create -o ashift=12 -O compression=zstd -O mountpoint=/data \
  #     tank mirror /dev/disk/by-id/<ssd-a> /dev/disk/by-id/<ssd-b>
  # ZFS then imports it automatically on boot (hostId below makes that safe).
  # ZFS is an out-of-tree module: it lags the newest kernels. The channel's
  # default kernel is kept ZFS-compatible, so do NOT switch boot.kernelPackages
  # to linuxPackages_latest here without checking ZFS supports it, or boot breaks.
  boot.supportedFilesystems = [ "zfs" ];
  # ZFS REQUIRES a unique 8-hex-char hostId; it refuses to import a pool without
  # one. Generated for this machine; do not reuse it on another host.
  networking.hostId = "72a21b30";
  services.zfs = {
    autoScrub.enable = true;             # monthly integrity scrub (repairs on redundant pools)
    trim.enable = true;                  # periodic SSD trim of the pool
    autoSnapshot.enable = true;          # rolling snapshots (frequent/hourly/daily/...)
  };

  system.stateVersion = "26.05";
}
