# airnix

Two machines, two ways to build them. This repo holds a **NixOS** flake and a
parallel **Arch Linux** setup for the same pair of computers, so either OS can
be installed on either machine without re-deriving the hardware quirks.

Repo: <https://github.com/shindakun/nixusb>

| Machine | Hardware | Wi-Fi chip | Driver |
| --- | --- | --- | --- |
| **MacBook Air** (6,x / 7,x) | Intel Haswell/Broadwell, Intel HD graphics | BCM4360 | proprietary `wl` (broadcom-sta / broadcom-wl) |
| **Dell XPS 8300** | 2011 Sandy Bridge, NVIDIA GTX 1060, several SSDs | BCM4313 (DW1501) | open in-kernel `brcmsmac` |

```text
airnix/
  Makefile        # dispatcher: nix-* -> nix/, arch-* -> arch/
  nix/            # the NixOS flake (niri + Noctalia, GNOME as fallback)
  arch/           # the Arch setup (niri + Noctalia)
```

The NixOS side is **installed and working on the Air**. The Arch side is
**written but not yet installed**; nothing in `arch/` has been run on real
hardware yet, so treat it as a tested-by-reading plan, not a proven install.

---

## The Wi-Fi problem (read this first)

This is the single hardest thing about both machines, and it drives most of the
design on both sides.

**The MacBook Air's BCM4360 has no good driver.** The only one that works is
Broadcom's abandoned proprietary blob (`broadcom-sta`, last released 2016). On
recent kernels its cfg80211 support is broken, which produces errors like
`wl_cfg80211_get_tx_power` and `wl_notify_scan_status`. The practical fallout:

- NetworkManager (`nmtui`), iwd (`iwctl`), and `wpa_supplicant -Dwext` **all fail**.
  NM and iwd need cfg80211 and get stuck `unavailable`, or the device shows up
  mislabeled as `eth0`.
- `brcmfmac` does **not** bind the 4360 without firmware neither distro ships.
  Switching to it is a dead end.
- What works is plain `wpa_supplicant` (no `-D` flag) plus `dhcpcd`, and **only
  from a clean device state**: a stale wpa_supplicant, NetworkManager, or iwd
  holding the card makes it fail.
- The open Broadcom stack must be blacklisted (`bcma`, `brcmsmac`, `brcmfmac`,
  `b43`) so `wl` owns the card. Otherwise `bcma` grabs it first.
- Do **not** over-specify `wpa.conf`. Bare `wpa_passphrase` output auto-negotiates
  and works; forcing `key_mgmt`/`proto`/`ieee80211w` broke association.

**The XPS's BCM4313 is fine.** `brcmsmac` is in-kernel and maintained, so
NetworkManager works normally. It only needs `b43` blacklisted, since `b43`
wrongly tries to claim the chip.

Because the two machines need *opposite* Broadcom setups (the Air needs `bcma`
gone, the XPS needs it loaded), **neither installer ISO can pick a driver at
boot**. Both ISOs boot neutral and give you a one-shot selector:

```bash
use-wl          # MacBook Air (BCM4360)
use-brcmsmac    # XPS 8300 (BCM4313)
```

### The Arch side has a fix the Nix side does not (yet)

On Arch, `linux-lts` is a first-class one-command install, and pairing it with
`broadcom-wl-dkms` is the standard fix: on an LTS kernel the driver's cfg80211
support is intact, so NetworkManager and `nmtui` behave normally and the
`wpa_supplicant` dance is unnecessary. `arch/install/chroot-setup.sh` therefore
makes **`linux-lts` the default boot entry on the Air** and keeps plain `linux`
as a fallback menu entry.

The same fix is available on NixOS by pinning `boot.kernelPackages`; it just
has not been done yet. Caveat: the LTS pairing is the widely-reported working
combination, but it has **not** been booted on this specific Air, so treat it as
the strong candidate fix rather than a confirmed one.

---

# NixOS (`nix/`)

A single flake configuring both machines plus one installer ISO. Shared user
environment (zsh, git, dev tools, fonts, the niri config) is written once in
Home Manager and used by both hosts.

```text
nix/
  flake.nix                       # 2 hosts + the installer ISO, wires Home Manager
  flake.lock                      # pinned inputs
  Makefile                        # Podman-based ISO build
  modules/
    common.nix                    # nix flakes, podman, user account, locale, base pkgs
    desktop.nix                   # GNOME, PipeWire, fonts
    niri.nix                      # niri compositor (coexists with GNOME)
    steam.nix                     # Steam + 32-bit graphics
  home/
    steve.nix                     # Home Manager: shared user env, links the configs below
    niri/config.kdl               # niri config (also used by the Arch side)
    niri/shell-v4.kdl             # spawns Noctalia v4, included by config.kdl (NixOS)
    niri/shell-v5.kdl             # spawns Noctalia v5, included by config.kdl (Arch)
  hosts/
    macbook-air/                  # wl Wi-Fi, applesmc, trackpad, thermals (+ real hardware config)
    xps-8300/                     # nvidia, brcmsmac Wi-Fi, ZFS, Incus, Grafana, Jellyfin
  iso/
    installer.nix                 # live USB (both Wi-Fi drivers + diagnostics)
```

Each host's `hardware-configuration.nix` is generated on that machine at install
time. The Air's real one is **committed**, so a fresh clone is install-ready.

## Build the ISO

The build runs in Podman because a NixOS ISO is a Linux artifact and Nix on
macOS only builds Darwin packages. On an Intel Mac the container is x86_64, so
it builds natively.

```bash
make nix-machine    # one-time: create/resize the Podman machine (6 GiB / 60 GiB)
make nix-iso        # build ./nix/nixusb-installer.iso
```

At the repo root every target is prefixed with the side it belongs to
(`nix-iso`, `arch-iso`), so neither OS is the implicit default. Nix targets:
`nix-iso`, `nix-fmt`, `nix-lock`, `nix-machine`, `nix-clean`.

Inside `nix/` the targets are unprefixed, since there the side is unambiguous:

```bash
cd nix && make iso
```

`make help` at the root lists every target on both sides. Running a bare
ambiguous name at the root (`make iso`) refuses and tells you the two prefixed
forms rather than guessing a side.

Flashing is deliberately **not** a make target so a stray `make` cannot `dd`
over a disk. See "Flashing" below.

`--memory 6144` and `--disk-size 60` matter: the build writes ~15-20 GB.

### Build troubleshooting

- **Sandbox error** (`could not set up a private mount namespace`): append
  `--option sandbox false` to the `nix build` command.
- **Out of space / killed:** `podman machine stop && podman machine set --memory 6144 --disk-size 60 && podman machine start`.
- **`broadcom-sta ... is marked as insecure`:** the version string drifted with a
  kernel bump. The error prints the new string; paste it into the
  `permittedInsecurePackages` lists in **both** `nix/iso/installer.nix` and
  `nix/hosts/macbook-air/configuration.nix`.
- **Apple Silicon Mac:** cannot build x86_64 natively. Build on an x86 Linux box,
  or emulate (slow) with `multiarch/qemu-user-static` plus `--platform linux/amd64`.

## Install

Boot the USB (Air: hold **Option** at power-on, pick EFI Boot. XPS: tap **F12**),
then:

```bash
use-wl                                     # or use-brcmsmac on the XPS
wifi-connect "YOUR_SSID" "YOUR_PASSWORD"   # 3rd arg = interface, defaults wlp3s0
ping nixos.org
```

Partition, format, and mount at `/mnt` (this **erases the disk**, run `lsblk`
first), then use the baked-in helpers:

```bash
nixusb-stage                     # copy the flake to /mnt/etc/nixos (writable)
nixusb-hwconfig macbook-air      # or: nixusb-hwconfig xps-8300
nixos-install --flake /mnt/etc/nixos#macbook-air
reboot
```

The whole flake rides along inside the ISO at `/iso/etc/nixos-install/nixusb`
(note the `/iso` prefix on the live system), so install works with no network.
After reboot, `passwd steve`.

> The Air's FaceTime camera fetches firmware at build time, so stay online for
> `nixos-install`.

## Day-to-day

On the Air the working copy is **`~/nixusb`** (owned by steve, so git needs no
sudo). Do not use `/etc/nixos`: a root-owned clone causes endless git
read-only/lock errors.

```bash
sudo nixos-rebuild switch --flake ~/nixusb/nix#macbook-air   # or #xps-8300
nix flake update --flake ~/nixusb/nix
```

The flake lives in the `nix/` subdirectory, so a flake ref pointing at the repo
root needs the subdir: `github:shindakun/nixusb?dir=nix#macbook-air`.

Pick **niri** at the GDM login screen; GNOME stays available as a fallback
session. `~/.config/niri/*` are read-only symlinks into `/nix/store`: edit
`nix/home/niri/config.kdl` and rebuild, never the files in `~/.config`. A
running niri live-reloads the config, includes and all.

---

# Arch Linux (`arch/`)

The same two machines with **niri** and **Noctalia**, and no GNOME. Package
lists are derived from the Nix config so the two sides stay comparable, and the
niri config is the same file the Nix side links.

```text
arch/
  Makefile          # check / iso / iso-podman / clean
  packages/
    base.txt          # shared: shell, dev tools, PipeWire, fonts, podman
    niri.txt          # niri, noctalia v5, xwayland-satellite, wofi, portals, greetd
    macbook-air.txt   # broadcom-wl-dkms, Intel mesa, tlp, thermald
    xps-8300.txt      # incus, prometheus, grafana, jellyfin
    aur.txt           # the four AUR exceptions (see "Repos, and the four exceptions")
  install/
    install.sh        # pacstrap + fstab + chroot, run from the live ISO
    chroot-setup.sh   # locale, user, modprobe blacklists, bootloader (called by install.sh)
    dotfiles.sh       # place the configs into ~/.config (run as your user, post-boot)
    aur.sh            # build the aur.txt exceptions (run as your user, post-boot)
    wifi-connect.sh   # the BCM4360 fallback sequence, ported from the NixOS ISO
  dotfiles/
    noctalia/config.toml  # Noctalia v5 settings (Arch only; the Air runs v4)
    zsh/zshrc             # matches the oh-my-zsh setup from home/steve.nix
                          # (the niri config comes from ../nix/home/niri/)
  iso/
    build.sh          # archiso ISO with broadcom-wl + helpers baked in
    README.md
```

## Build the ISO

`archiso` needs an Arch host; it does not run on macOS, because it drives
pacman/pacstrap against the live Arch package DB. Two ways to build:

```bash
# On an Arch host (the XPS, once it runs Arch):
make arch-iso

# From macOS, building inside an archlinux:latest container:
make arch-iso-podman
```

The container build has two requirements, both of which will otherwise fail the
build partway through:

- **The Podman machine must be rootful.** `pacstrap` mounts `/dev` as a
  devtmpfs, which a rootless machine cannot create regardless of `--privileged`
  (that flag only grants privileges the engine already has). Fix it once with
  `podman machine stop && podman machine set --rootful && podman machine start`.
  `make arch-iso-podman` checks this before starting.
- **The build tree stays off the macOS file share.** pacman cannot lock its
  database over virtiofs, so `build.sh` takes a `BUILD_DIR` (the Makefile passes
  container-local `/build`) and copies only the finished ISO back to
  `arch/iso/out/`.

Either writes `arch/iso/out/airnix-arch-<date>.iso`. Both run
`arch/iso/build.sh`, which you can also call directly with `sudo ./iso/build.sh`
from `arch/`. Inside `arch/` the targets are unprefixed (`make iso`,
`make iso-podman`, `make check`, `make clean`).

Before building, `make arch-check` syntax-checks every script, confirms the
package lists are non-empty, and runs `niri validate` and
`noctalia config validate` on the shared configs if those binaries are
installed. It is the default target, so a bare `make` inside `arch/` runs it.

This bakes in `broadcom-wl-dkms`, `linux-lts`, the `use-wl` / `use-brcmsmac` /
`wifi-connect` helpers, and the whole repo at `/root/airnix`. The stock Arch ISO
works fine on the XPS, but cannot get the Air online, which is why this exists.

## Install

Boot the USB, pick the Wi-Fi driver, get online:

```bash
use-wl                          # or use-brcmsmac on the XPS
nmtui                           # should work on the LTS kernel
# fallback if the card misbehaves:
wifi-connect "YOUR_SSID" "YOUR_PASSWORD"
```

Partition, format, and mount at `/mnt` **by hand** (the script deliberately does
not do this). UEFI layout, matching what the NixOS side uses:

```bash
lsblk                                    # confirm the target disk first
parted /dev/sdX -- mklabel gpt
parted /dev/sdX -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sdX -- set 1 esp on
parted /dev/sdX -- mkpart primary 512MiB 100%

mkfs.fat -F32 /dev/sdX1
mkfs.ext4 /dev/sdX2

mount /dev/sdX2 /mnt
mkdir -p /mnt/boot
mount /dev/sdX1 /mnt/boot
```

Then run the installer and finish up:

```bash
cd /root/airnix/arch
./install/install.sh macbook-air         # or: xps-8300

arch-chroot /mnt passwd                  # root password
arch-chroot /mnt passwd steve            # user password
reboot

# after first boot, as steve:
cd /root/airnix/arch && ./install/dotfiles.sh
./install/aur.sh                         # the AUR exceptions, see below
```

`install.sh` runs `pacstrap` with `base.txt` + `niri.txt` + the host list,
generates `fstab`, copies the repo to `/root/airnix`, and hands off to
`chroot-setup.sh` for locale, user, module blacklists, systemd-boot entries, and
a greetd config that launches `niri-session` through tuigreet.

## Repos, and the four exceptions

The base install uses **official repos only**. It runs as root from the live
ISO, `makepkg` refuses to run as root, and AUR PKGBUILDs compile from upstream
at install time, so putting them in the path that has to work before the machine
boots would mean bootstrapping a helper mid-install and accepting builds that
break on any kernel bump.

Four packages have no repo alternative, so they live in `packages/aur.txt` and
are built **after first boot** by `install/aur.sh`, as your normal user. Nothing
there is needed to boot. The script bootstraps `paru` from a plain clone on
first run and filters the list by host, so the Air does not build a GPU driver.

| Package | Why |
| --- | --- |
| `nvidia-580xx-dkms` + `-utils` + `-settings` | The only driver that works on the XPS. Arch dropped the proprietary `nvidia` package; the repos now carry only `nvidia-open` (615.x), whose open kernel modules need Turing or newer. Pascal (GTX 10xx) was dropped after branch 580. Without it the card runs on nouveau, which has no NVENC, so Jellyfin transcodes on the CPU. NixOS pins the same branch declaratively with `hardware.nvidia.branch = "legacy_580"`. |
| `claude-code` | Not in the Arch repos; it is a normal package on NixOS. `npm install -g @anthropic-ai/claude-code` works just as well if you would rather keep the list to the driver alone. |
| `mbpfan` | Optional. Fan curves on the Air; thermald plus the kernel's applesmc handling cover it otherwise. |

DKMS packages rebuild on kernel updates. If the display fails to come up after
an update, check `dkms status` before anything else.

ZFS on the XPS is a separate case with the same shape: not in the repos, and
deliberately not automated. See "XPS: ZFS data pool" below.

---

## niri + Noctalia (both distros)

niri is scrollable tiling: windows sit on an infinite horizontal strip per
workspace rather than in a split tree. `Super+Left/Right` moves along the strip,
`Super+Up/Down` moves within a column, `Super+O` opens the overview.

Noctalia is the desktop shell: bar, launcher, notifications, clipboard history,
lock screen, wallpaper, OSDs. niri starts it at login, so nothing else (waybar,
mako, swaylock, ...) is installed. The binds:

| Keys | Action |
| --- | --- |
| `Super+Return` | terminal (kitty) |
| `Super+D` | launcher (wofi) |
| `Super+E` | files (nautilus) |
| `Super+Q` | close window |
| `Super+V` | float / unfloat |
| `Super+F` / `Super+Shift+F` | fullscreen / maximize column |
| `Super+R` | cycle preset column width, up to full width |
| `Super+-` / `Super+=` | shrink / grow column by 10% |
| `Super+Left/Right` | move along the strip |
| `Super+Up/Down` | move within a column |
| `Super+1..4` / `Super+Shift+1..4` | focus / move to workspace |
| `Print` | region screenshot to the clipboard |
| `Super+Shift+M` | quit niri |

The config is validated by `make arch-check` when `niri` is on the host
(`niri validate`), along with the Arch-side Noctalia config when `noctalia` is.

### The one place the two distros differ

The Air runs **Noctalia v4** (`noctalia-shell`, the Quickshell build), which is
what has actually been tested on hardware. Arch does not package v4 at all, in
the repos or the AUR, so it gets **v5** (`noctalia`, the native rewrite). v5 is
a fresh install rather than an upgrade, with its own config format, so the two
are separate setups.

`config.kdl` therefore ends with nothing compositor-specific and starts with
`include "shell.kdl"`, and each side drops in the right one: Home Manager links
`shell-v4.kdl`, `arch/install/dotfiles.sh` copies `shell-v5.kdl`. Everything
else in the niri config is shared byte for byte. Moving the Air to v5 later
means swapping that one link and adding a `config.toml`.

**X11 apps:** niri has no built-in XWayland. It creates the X11 socket itself
and starts `xwayland-satellite` (on PATH on both distros) the first time an X11
client connects. Do not start it or set `DISPLAY` by hand; that breaks the
built-in handling.

## XPS: ZFS data pool

Root stays **ext4** on both distros; ZFS is only the data pool across the extra
SSDs. On NixOS this is declarative (`boot.supportedFilesystems`, `networking.hostId`).

On Arch, ZFS is **not in the official repos**. Pick one:

- **AUR:** `zfs-dkms` + `zfs-utils` (rebuilds per kernel, can lag new kernels)
- **archzfs** unofficial repo (prebuilt)

`install.sh` does not install ZFS automatically for this reason. Create the pool
by hand once, matching the actual disks:

```bash
zpool create -o ashift=12 -O compression=zstd -O mountpoint=/data \
  tank mirror /dev/disk/by-id/<ssd-a> /dev/disk/by-id/<ssd-b>
# 3+ disks with one-disk fault tolerance: swap `mirror ...` for `raidz <a> <b> <c>`
zfs set com.sun:auto-snapshot=true tank
```

ZFS is out-of-tree and lags the newest kernels, so do not chase the latest
kernel on the XPS if you rely on the pool.

---

## What each machine gets

Shared across both distros: zsh + plugins, git/gh/lazygit/direnv, vim,
ripgrep/fd/bat/eza/jq/fzf, Firefox + Chromium, mpv, Podman, PipeWire, Fira Code
and Nerd Fonts, micro, delta, glow, and niri + Noctalia (NixOS also keeps GNOME
as a fallback session).

### Toolchains

The same set on both distros. `nix/home/steve.nix` and `arch/packages/base.txt`
are kept in step; versions differ because Arch is rolling and NixOS 26.05 is a
frozen release.

| | Compilers and runtimes | Tooling |
| --- | --- | --- |
| C / C++ | gcc, cmake, make, pkg-config | |
| Go | go | gopls |
| Rust | rustc, cargo (Arch: the `rust` package) | clippy, rustfmt, rust-analyzer |
| Node | nodejs, npm, pnpm | typescript-language-server |
| Python | python 3, uv (no pip: uv covers envs, installs, and tool runs) | ruff |
| Editors | vim, micro | delta, glow |
| Shell | | shellcheck, shfmt |
| Nix | | nil, nixpkgs-fmt (NixOS only) |

Editors are VS Code and Zed on both. Two Arch caveats: its `code` package is the
OSS build, so extensions come from Open VSX rather than the Microsoft
marketplace, and `claude-code` is not in the Arch repos, so install it with
`npm install -g @anthropic-ai/claude-code` (it is a normal package on NixOS).

**MacBook Air:** `wl` Wi-Fi, applesmc (fans/temps/backlight), FaceTime camera
(NixOS), trackpad tap-to-click and natural scrolling, TLP + thermald. The
integrated Intel GPU limits gaming to light titles.

**XPS 8300:** NVIDIA GTX 1060 (proprietary driver, modesetting on for Wayland),
`brcmsmac` Wi-Fi, ZFS data pool, Incus for system containers and VMs (including
Home Assistant OS), key-only SSH, Prometheus + Grafana on `:3000`, and Jellyfin
on `:8096` with NVENC transcoding.

---

## Flashing an ISO

**Do not use Ventoy on Macs** (boot problems on Apple EFI). Use `dd`.

macOS (find N with `diskutil list`, unmount first):

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=<image>.iso of=/dev/rdiskN bs=4m
```

Linux:

```bash
sudo dd if=<image>.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Double-check the device: `dd` erases the wrong disk without complaint.

## Booting the target machine

- **MacBook Air:** plug in the USB, power on, immediately hold **Option**, pick
  the **EFI Boot** drive. No T2, so no Secure Boot to disable.
- **XPS 8300:** tap **F12** at the Dell logo for the one-time boot menu. Both
  configs assume **UEFI**; for legacy BIOS on the XPS use GRUB instead of
  systemd-boot (see the note in its config).
