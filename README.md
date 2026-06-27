# nixusb: multi-host NixOS flake (MacBook Air + Dell XPS 8300)

A single flake that configures two machines and builds one **installer ISO**
that can get online over Wi-Fi on both of them.

Repo: <https://github.com/shindakun/nixusb>

- **MacBook Air** (older Intel, BCM4360 Wi-Fi): needs the proprietary Broadcom
  `wl` driver, Apple SMC (fans/temps/backlight), laptop power tuning.
- **Dell XPS 8300** (Sandy Bridge desktop, NVIDIA GTX 1060, Dell DW1501 /
  BCM4313 Wi-Fi): NVIDIA proprietary driver, open `brcmsmac` Wi-Fi.

Shared user environment (zsh + oh-my-zsh, git, dev tools, fonts, Hyprland) is
written once in Home Manager and used by both machines.

## Layout

```text
nixusb/
  flake.nix                       # 2 hosts + the installer ISO, wires Home Manager
  flake.lock                      # pinned inputs (regenerated on first build; keep it)
  modules/
    common.nix                    # nix flakes, podman, user account, locale, base pkgs
    desktop.nix                   # GNOME, PipeWire, fonts
    hyprland.nix                  # Hyprland compositor (coexists with GNOME)
  home/
    steve.nix                     # Home Manager: shared user env + Hyprland config
  hosts/
    macbook-air/configuration.nix # Air hardware: wl Wi-Fi, applesmc, trackpad, thermals
    xps-8300/configuration.nix    # XPS hardware: nvidia, brcmsmac Wi-Fi
  iso/
    installer.nix                 # live USB (both Wi-Fi drivers)
```

Each host's `hardware-configuration.nix` is generated on that machine during
install (see below) and dropped into its `hosts/<name>/` directory.

---

## Step 0: the Wi-Fi situation (why the custom ISO exists)

The stock NixOS ISO can't join Wi-Fi on either machine out of the box:

| Machine | Wi-Fi chip | Driver |
| --- | --- | --- |
| MacBook Air (6,x / 7,x) | BCM4360 | proprietary `wl` (broadcom_sta) |
| XPS 8300 (DW1501) | BCM4313 | open `brcmsmac` + firmware |

The installer ISO loads `wl` for the Air's 4360 and keeps `brcmsmac` available
for the XPS's 4313. Each driver binds only its own card by PCI id, so one ISO
serves both. `b43` is blacklisted (it would wrongly grab the 4313).

> Note on `wl`: nixpkgs flags `broadcom_sta` as insecure (CVE-2019-9501/9502),
> an unmaintained proprietary driver. It's the only option for the BCM4360, so
> the config permits it via `nixpkgs.config.permittedInsecurePackages`. Low
> practical risk on trusted networks. The XPS's `brcmsmac` is open and in-kernel,
> no such caveat.
>
> If a kernel bump changes the `broadcom-sta` version suffix, the build fails
> with the exact new string; paste it into the `permittedInsecurePackages` lists
> in `iso/installer.nix` and `hosts/macbook-air/configuration.nix`.

---

## Step 1: Build the installer ISO

A NixOS ISO is a Linux artifact and Nix on macOS only builds Darwin packages,
so the build runs inside a Linux container via **Podman**. On an Intel Mac that
container is x86_64, so it builds the x86_64 ISO natively.

One-time Podman setup:

```bash
brew install podman
podman machine init --cpus 4 --memory 6144 --disk-size 60
podman machine start
podman machine ssh uname -m            # expect: x86_64
```

`--memory 6144` and `--disk-size 60` matter: the build writes ~15-20 GB and is
memory-hungry. Resize an existing machine without recreating it:
`podman machine stop && podman machine set --memory 6144 && podman machine start`.

Build it. The `Makefile` wraps the Podman incantation:

```bash
make machine    # one-time: create/resize the Podman machine (6 GiB / 60 GiB)
make iso        # build the ISO into ./nixusb-installer.iso
```

All `make` targets:

| Target | What it does |
| --- | --- |
| `make iso` | Build the ISO into `./nixusb-installer.iso` (default target). |
| `make lock` | (Re)generate `flake.lock` without building. |
| `make machine` | One-time: create or resize the Podman machine to 6 GiB / 60 GiB. |
| `make clean` | Remove the built ISO. |
| `make help` | List the targets. |

Flashing is intentionally not a `make` target, so a stray `make` can't `dd`
over a disk; flash manually (Step 2).

Or run the underlying build command directly (from the folder with `flake.nix`):

```bash
podman run --rm --privileged \
  -v "$PWD":/work -w /work \
  docker.io/nixos/nix:latest \
  sh -c "nix --extra-experimental-features 'nix-command flakes' \
            build '.#nixosConfigurations.installer.config.system.build.isoImage' \
         && cp -vL result/iso/*.iso /work/nixusb-installer.iso \
         && rm -f /work/result"
```

When done you'll have **`nixusb-installer.iso`** (~1.4 GB) in the
folder. The trailing `cp` is essential: inside the container the ISO lands in
`/nix/store`, which disappears when the container exits, so the `result` symlink
would be dead from the Mac's side. Copying the real file out is what leaves a
usable ISO.

### Build troubleshooting

- **Sandbox error** (`could not set up a private mount namespace`): append
  `--option sandbox false` to the `nix ... build` part.
- **Out of space / killed:** machine too small. `podman machine stop`, then
  `podman machine set --memory 6144 --disk-size 60`, `podman machine start`.
- **`broadcom-sta ... is marked as insecure`:** version string drifted; see the
  note in Step 0.
- **Apple Silicon Mac:** can't build x86_64 natively. Build on a real x86 Linux
  box, or emulate (slow): register with
  `podman run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p yes`
  and add `--platform linux/amd64 ... --option filter-syscalls false`.

---

## Step 2: Flash the ISO to a USB stick

**Don't use Ventoy on Macs** (boot problems on Apple EFI). Use `dd`.

macOS (find N with `diskutil list`, unmount first):

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=nixusb-installer.iso of=/dev/rdiskN bs=4m
```

Linux:

```bash
sudo dd if=nixusb-installer.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Double-check the device: `dd` erases the wrong disk without complaint.

---

## Step 3: Boot the target machine

- **MacBook Air:** plug in the USB, power on, immediately hold **Option (⌥)**,
  pick the **EFI Boot** drive, then the default NixOS entry. (No T2, so no
  Secure Boot to disable.)
- **XPS 8300:** tap **F12** at the Dell logo for the one-time boot menu, pick the
  USB. If you installed in UEFI mode choose the UEFI USB entry; the host config
  assumes UEFI (see the note in its file for legacy BIOS).

You land at a root shell on the live system.

---

## Step 4: Install (flake-based, the same flow on both machines)

Join Wi-Fi:

```bash
nmtui            # "Activate a connection", pick your SSID
ping nixos.org   # confirm you're online
```

Partition, format, and mount. This **erases the disk**, so run `lsblk` first
(the disk is often `/dev/sda` or `/dev/nvme0n1`):

```bash
sudo -i
parted /dev/sdX -- mklabel gpt
parted /dev/sdX -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sdX -- set 1 esp on
parted /dev/sdX -- mkpart primary 512MiB 100%

mkfs.fat -F32 -n BOOT /dev/sdX1
mkfs.ext4 -L nixos /dev/sdX2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/BOOT /mnt/boot
```

Get this flake onto the target and generate the machine's hardware config:

```bash
# Clone the flake (or copy it from a second USB) to /mnt/etc/nixos:
git clone https://github.com/shindakun/nixusb /mnt/etc/nixos
# Generate hardware-configuration.nix for THIS machine into a temp dir:
nixos-generate-config --root /mnt --dir /tmp/hwcfg
```

Put the generated `hardware-configuration.nix` where the host expects it:

```bash
# MacBook Air:
cp /tmp/hwcfg/hardware-configuration.nix /mnt/etc/nixos/hosts/macbook-air/
# or XPS 8300:
cp /tmp/hwcfg/hardware-configuration.nix /mnt/etc/nixos/hosts/xps-8300/
```

Install the right host and reboot:

```bash
# Air:
nixos-install --flake /mnt/etc/nixos#macbook-air
# XPS:
nixos-install --flake /mnt/etc/nixos#xps-8300

reboot
```

`nixos-install` prompts for a root password at the end. After reboot, log in
and set steve's password: `passwd steve`.

> The Air's FaceTime camera downloads firmware at build time, so stay online for
> `nixos-install`.

---

## What both machines get

From the shared modules and Home Manager:

- **Nix:** flakes + the new `nix` CLI enabled by default.
- **Desktop:** GNOME (GDM) and **Hyprland** both available; pick the session at
  login. Hyprland setup: waybar, wofi, mako, kitty, hyprpaper, hyprlock, grim/slurp.
- **Shell:** zsh + oh-my-zsh (autosuggestions, syntax highlighting; git/direnv/
  fzf/sudo plugins), steve's login shell.
- **Dev:** git (+lfs), gh, direnv (+nix-direnv), claude-code, nodejs, ripgrep,
  fd, bat, eza, jq, httpie, fzf, tmux, nil, nixpkgs-fmt, cmake, gcc, go, gnumake.
- **Containers:** Podman with docker-compat.
- **Gaming:** Steam (with the 32-bit graphics stack and Remote Play firewall).
- **Audio:** PipeWire. **Fonts:** Fira Code + Nerd Font variants, Linux Libertine.

Per machine:

- **Air:** `wl` Wi-Fi, applesmc, FaceTime camera, trackpad (tap + natural scroll),
  thermald + TLP. Steam runs but the integrated Intel GPU limits it to light titles.
- **XPS:** NVIDIA GTX 1060 (proprietary driver, modesetting on for Wayland),
  `brcmsmac` Wi-Fi, **Incus** (system containers + VMs) alongside Podman, and the
  GPU that actually makes Steam worthwhile.

---

## Day-to-day

Rebuild after editing the flake (on the machine itself):

```bash
sudo nixos-rebuild switch --flake /etc/nixos#macbook-air   # or #xps-8300
```

Update inputs (nixpkgs, home-manager, nixos-hardware):

```bash
nix flake update /etc/nixos
```

---

## Editing the desktop / shell / Hyprland

- **Swap GNOME** for KDE or Xfce: edit `modules/desktop.nix` once, both hosts
  follow.
- **Hyprland keybinds / bar / launcher:** all in `home/steve.nix` under
  `wayland.windowManager.hyprland` and the Hyprland package list.
- **oh-my-zsh theme / plugins:** `home/steve.nix`, `programs.zsh.ohMyZsh`.
- **Your git identity:** `home/steve.nix`, `programs.git.settings.user.name` /
  `programs.git.settings.user.email`.
