# arch: build the Arch installer ISO and check the scripts.
#
# Unlike the Nix side, this CANNOT run on macOS: archiso drives pacman/pacstrap
# against the live Arch package DB, so `make iso` needs an Arch host. Either run
# it on an Arch box (the XPS, once it runs Arch) or use the container target,
# which does the whole build inside archlinux:latest via Podman.
#
# Common targets:
#   make check        syntax-check every script + validate the configs
#   make iso          build the ISO (must be ON Arch, needs root)
#   make iso-podman   build the ISO inside an Arch container (works from macOS)
#   make clean        remove archiso build artifacts
#
# Flashing is deliberately NOT a target here (same rule as the Nix side) so a
# stray `make` cannot dd over a disk. See the root README.

ARCH_IMAGE  := docker.io/library/archlinux:latest
SCRIPTS     := $(wildcard install/*.sh) iso/build.sh
PKGLISTS    := $(wildcard packages/*.txt)
OUT         := iso/out

.DEFAULT_GOAL := check

.PHONY: check iso iso-podman clean help

## Syntax-check every shell script and validate the package lists + configs.
check:
	@echo "==> bash -n on every script"
	@for f in $(SCRIPTS); do bash -n "$$f" && echo "  OK   $$f" || exit 1; done
	@echo "==> scripts are executable"
	@for f in $(SCRIPTS); do test -x "$$f" && echo "  OK   $$f" \
	  || { echo "  FAIL $$f is not executable (chmod +x)"; exit 1; }; done
	@echo "==> package lists are non-empty after stripping comments"
	@for f in $(PKGLISTS); do \
	  n=$$(grep -vcE '^\s*(#|$$)' "$$f"); \
	  test "$$n" -gt 0 && echo "  OK   $$f ($$n pkgs)" \
	    || { echo "  FAIL $$f has no packages"; exit 1; }; done
	@echo "==> waybar config is valid JSON (comments stripped)"
	@python3 -c "import json,re,sys; \
	  s=open('dotfiles/waybar/config.jsonc').read(); \
	  json.loads(re.sub(r'^\s*//.*$$','',s,flags=re.M)); \
	  print('  OK   dotfiles/waybar/config.jsonc')"
	@echo "==> niri config parses (needs niri; skipped if absent)"
	@command -v niri >/dev/null \
	  && { niri validate -c dotfiles/niri/config.kdl \
	       && echo "  OK   dotfiles/niri/config.kdl"; } \
	  || echo "  SKIP niri not installed (validate on the target machine)"
	@echo "==> all checks passed"

## Build the installer ISO. Must run ON Arch, as root.
iso:
	@command -v mkarchiso >/dev/null \
	  || { echo "mkarchiso not found. This target needs an Arch host with archiso."; \
	       echo "From macOS use:  make iso-podman   (or 'make arch-iso-podman' from the repo root)"; \
	       exit 1; }
	sudo ./iso/build.sh
	@echo "==> ISO in $(OUT)/"

## Build the ISO inside an Arch container (works from macOS on x86_64).
# Two hard requirements, both learned by hitting them:
#
#  1. The Podman machine must be ROOTFUL. pacstrap mounts /dev as a devtmpfs,
#     which a rootless machine cannot create no matter what --privileged says
#     (it only grants privileges the engine itself has). Fix:
#       podman machine stop && podman machine set --rootful && podman machine start
#
#  2. BUILD_DIR must be CONTAINER-LOCAL (/build), not the virtiofs share.
#     pacman cannot lock its database on virtiofs, so pacstrap fails with
#     "unable to lock database". build.sh copies the finished ISO back to
#     iso/out/ on the share.
iso-podman:
	@podman machine inspect --format '{{.Rootful}}' 2>/dev/null | grep -qx true \
	  || { echo "The Podman machine is ROOTLESS; pacstrap cannot mount devtmpfs."; \
	       echo "Make it rootful first:"; \
	       echo "  podman machine stop && podman machine set --rootful && podman machine start"; \
	       exit 1; }
	podman run --rm --privileged -v "$(CURDIR)/..":/work -w /work/arch \
	  $(ARCH_IMAGE) bash -c "\
	    pacman -Sy --noconfirm --needed archiso rsync && \
	    BUILD_DIR=/build ./iso/build.sh"
	@echo "==> ISO in $(OUT)/"

## Remove archiso build artifacts (work/, out/, the generated profile/).
clean:
	rm -rf iso/work iso/out iso/profile

## List targets.
# Pairs each `## text` with the next target line, tolerating extra comment
# lines in between (a plain `grep -B1` drops those targets).
help:
	@awk '/^## /{d=substr($$0,4); next} \
	      /^[a-z][a-z0-9-]*:/{if(d){split($$0,a,":"); printf "  %-12s %s\n", a[1], d; d=""}} \
	      /^[^#]/{if($$0 !~ /^[a-z]/) d=""}' Makefile
