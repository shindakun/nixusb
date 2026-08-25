# Custom Arch installer ISO

The stock Arch ISO cannot get online on the MacBook Air's BCM4360: the ISO
carries no `broadcom-wl` module and there is no network to fetch one with. Same
chicken-and-egg the NixOS side has. This directory builds an ISO with the
driver and the helper scripts baked in.

The XPS 8300's BCM4313 uses in-kernel `brcmsmac`, so the stock ISO already works
there. This ISO serves both anyway: one stick, two machines.

## Requirements

`archiso` must run on an Arch Linux host (it uses pacman/pacstrap against the
live package DB). It does not run natively on macOS. Options:

- an existing Arch box
- an Arch container on the Mac, via `make iso-podman` (see the caveats below)
- the XPS itself, once it is running Arch, to build the Air's ISO

## Build

On a native Arch host:

```bash
sudo pacman -S archiso
sudo ./build.sh          # writes out/airnix-arch-<date>.iso
```

From macOS, in a container:

```bash
make iso-podman          # from arch/, or `make arch-iso-podman` from the root
```

### Two container gotchas (both hit in practice)

**The Podman machine must be rootful.** `pacstrap` mounts `/dev` as a devtmpfs,
and a *rootless* machine cannot create one no matter what `--privileged` says:
that flag only grants privileges the container engine itself already has. The
symptom is:

```
mount: /.../airootfs/dev: permission denied.
==> ERROR: failed to setup chroot
```

Fix it once:

```bash
podman machine stop
podman machine set --rootful
podman machine start
```

`make iso-podman` checks this up front and refuses with the same instructions
rather than failing halfway through a long build.

**The build tree cannot live on the macOS file share.** The repo reaches the
container over virtiofs, and pacman cannot lock its database there, so pacstrap
dies with `unable to lock database` even after the mount problem is solved.
`build.sh` therefore takes a `BUILD_DIR` environment variable; the Makefile sets
`BUILD_DIR=/build` (container-local storage) and only the finished ISO is copied
back to `out/` on the share. On a native Arch host `BUILD_DIR` defaults to this
directory, which is fine.

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
