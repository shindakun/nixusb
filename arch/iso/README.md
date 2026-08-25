# Custom Arch installer ISO

The stock Arch ISO cannot get online on the MacBook Air's BCM4360: the ISO
carries no `broadcom-wl` module and there is no network to fetch one with. Same
chicken-and-egg the NixOS side has. This directory builds an ISO with the
driver and the helper scripts baked in.

The XPS 8300's BCM4313 uses in-kernel `brcmsmac`, so the stock ISO already works
there. This ISO serves both anyway: one stick, two machines.

## Requirements

`archiso` must run on an Arch Linux host (it uses pacman/pacstrap against the
live package DB). It does not run on macOS. Options:

- an existing Arch box
- an Arch container on the Mac:
  `podman run --rm --privileged -v "$PWD":/work -w /work archlinux:latest`
  (install archiso inside, then run `build.sh`)
- the XPS itself, once it is running Arch, to build the Air's ISO

## Build

```bash
sudo pacman -S archiso
sudo ./build.sh          # writes out/airnix-arch-<date>.iso
```

## What is baked in

- `broadcom-wl-dkms` + `linux-lts` + headers, so `wl` is available at boot
- `wifi-connect`, `use-wl`, `use-brcmsmac` helpers (same names as the NixOS ISO)
- the whole repo at `/root/airnix`, so install works with no network

## Wi-Fi on the live system

The ISO boots NEUTRAL: it loads neither Broadcom driver, exactly like the NixOS
ISO, because the two machines need opposite setups (the Air needs `bcma` gone,
the XPS needs it). Pick per machine:

```bash
use-wl          # MacBook Air  (BCM4360)  -> proprietary wl
use-brcmsmac    # XPS 8300     (BCM4313)  -> open brcmsmac
```

Then join a network. On the XPS, `nmtui` works normally. On the Air, try
`nmtui` first (on the LTS kernel it should work); if the card misbehaves, fall
back to `wifi-connect "SSID" "PASSWORD"`.
