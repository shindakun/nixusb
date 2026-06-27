# nixusb: build the NixOS installer ISO via Podman.
#
# A NixOS ISO is a Linux artifact and Nix on macOS only builds Darwin packages,
# so every nix command runs inside a Linux container. On an Intel Mac that
# container is x86_64, so the x86_64 ISO builds natively.
#
# Common targets:
#   make machine   one-time: create/resize the Podman machine (6 GiB, 60 GiB)
#   make iso       build the installer ISO into ./$(ISO_NAME)
#   make fmt       format every .nix file with nixpkgs-fmt
#   make lock      (re)generate flake.lock
#   make clean     remove the built ISO
#
# Flash the result yourself with dd (see the README); deliberately not a target
# here so a stray `make` can't dd over a disk.

ISO_NAME      := nixusb-installer.iso
NIX_IMAGE     := docker.io/nixos/nix:latest
# A literal '#': bare '#' starts a comment in make, so build it from its char code.
HASH          := $(shell printf '\043')
ISO_ATTR      := .$(HASH)nixosConfigurations.installer.config.system.build.isoImage
NIX           := nix --extra-experimental-features 'nix-command flakes'

# Run a shell snippet inside the nix container with the repo bind-mounted at /work.
PODMAN_RUN = podman run --rm --privileged -v "$(CURDIR)":/work -w /work $(NIX_IMAGE) sh -c

.DEFAULT_GOAL := iso

.PHONY: iso fmt lock machine clean help

## Build the installer ISO and copy it out to ./$(ISO_NAME).
iso:
	$(PODMAN_RUN) "$(NIX) build '$(ISO_ATTR)' \
	  && cp -vL result/iso/*.iso /work/$(ISO_NAME) \
	  && rm -f /work/result"
	@echo "==> built ./$(ISO_NAME)"

## Format every .nix file in the tree with nixpkgs-fmt.
fmt:
	$(PODMAN_RUN) "$(NIX) run nixpkgs#nixpkgs-fmt -- ."

## (Re)generate flake.lock without building anything.
lock:
	$(PODMAN_RUN) "$(NIX) flake lock"

## One-time Podman machine setup (or resize an existing one to 6 GiB / 60 GiB).
machine:
	@podman machine inspect >/dev/null 2>&1 \
	  && { echo "==> resizing existing machine to 6 GiB"; \
	       podman machine stop; \
	       podman machine set --cpus 4 --memory 6144 --disk-size 60; \
	       podman machine start; } \
	  || { echo "==> creating machine (4 cpu / 6 GiB / 60 GiB)"; \
	       podman machine init --cpus 4 --memory 6144 --disk-size 60; \
	       podman machine start; }
	@podman machine ssh uname -m

## Remove the built ISO. (The `iso` step manages its own `result` symlink.)
clean:
	rm -f $(ISO_NAME)

## List targets.
help:
	@grep -B1 -E '^[a-z].*:' Makefile | grep -E '^##|^[a-z]' | sed 's/^## /  /'
