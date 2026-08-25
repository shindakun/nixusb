# Root dispatcher. The real Makefiles live in nix/ and arch/; this forwards to
# them so you can drive either side from the repo root.
#
#   make iso          the NixOS installer ISO   (-> nix/)
#   make arch-iso     the Arch installer ISO    (-> arch/)
#   make check        check both sides
#
# Nix targets go to nix/; Arch targets are prefixed `arch-` because both sides
# define `iso` and `clean` and they must not collide.

.DEFAULT_GOAL := help

.PHONY: iso fmt lock machine clean check help \
        arch-iso arch-iso-podman arch-check arch-clean

# ---- NixOS side (nix/Makefile) ---------------------------------------
iso fmt lock machine clean:
	@$(MAKE) -C nix $@

# ---- Arch side (arch/Makefile) ---------------------------------------
# Strip the `arch-` prefix and hand the rest to arch/Makefile.
arch-iso arch-iso-podman arch-check arch-clean:
	@$(MAKE) -C arch $(patsubst arch-%,%,$@)

## Check both sides (nix formatting is a no-op without Podman running).
check: arch-check

help:
	@echo "airnix. Two OS setups for the same two machines."
	@echo
	@echo "NixOS (nix/):"
	@echo "  make iso           build the NixOS installer ISO (via Podman)"
	@echo "  make machine       one-time Podman machine setup"
	@echo "  make fmt           nixpkgs-fmt every .nix file"
	@echo "  make lock          regenerate flake.lock"
	@echo "  make clean         remove the built ISO"
	@echo
	@echo "Arch (arch/):"
	@echo "  make arch-check    syntax-check scripts + validate configs"
	@echo "  make arch-iso      build the Arch ISO (needs an Arch host)"
	@echo "  make arch-iso-podman  build the Arch ISO in a container"
	@echo "  make arch-clean    remove archiso build artifacts"
	@echo
	@echo "Both:"
	@echo "  make check         run every check that works on this host"
	@echo
	@echo "Flashing is deliberately not a target; see the README."
