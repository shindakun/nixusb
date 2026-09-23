# Root dispatcher. The real Makefiles live in nix/ and arch/; this forwards to
# them so you can drive either side from the repo root.
#
# Every target is prefixed with the side it belongs to. Neither OS is the
# default: `make iso` is ambiguous here and says so rather than guessing.
#
#   make nix-iso      the NixOS installer ISO   (-> nix/)
#   make arch-iso     the Arch installer ISO    (-> arch/)
#   make check        run every check that works on this host
#
# Inside nix/ and arch/ the targets are unprefixed (`make iso`), since there
# the side is unambiguous.

NIX_TARGETS  := iso fmt lock machine clean
ARCH_TARGETS := iso iso-podman check clean

.DEFAULT_GOAL := help

.PHONY: help check \
        $(addprefix nix-,$(NIX_TARGETS)) \
        $(addprefix arch-,$(ARCH_TARGETS)) \
        iso clean fmt lock machine iso-podman

# ---- NixOS side (nix/Makefile) ---------------------------------------
# Strip the `nix-` prefix and hand the rest to nix/Makefile.
$(addprefix nix-,$(NIX_TARGETS)):
	@$(MAKE) -C nix $(patsubst nix-%,%,$@)

# ---- Arch side (arch/Makefile) ---------------------------------------
$(addprefix arch-,$(ARCH_TARGETS)):
	@$(MAKE) -C arch $(patsubst arch-%,%,$@)

# ---- Bare names ------------------------------------------------------
# `iso` and `clean` exist on BOTH sides, so refuse and name the two options.
# The rest exist on one side only, so just point at the prefixed form.
iso clean:
	@printf "'%s' is ambiguous at the repo root: both sides define it.\n" "$@" >&2
	@printf "Use:  make nix-%s   or   make arch-%s\n" "$@" "$@" >&2
	@exit 1

fmt lock machine:
	@printf "Use 'make nix-%s' at the repo root (this target is NixOS-only).\n" "$@" >&2
	@exit 1

iso-podman:
	@printf "Use 'make arch-iso-podman' at the repo root (this target is Arch-only).\n" >&2
	@exit 1

## Run every check that works on this host.
check: arch-check

help:
	@echo "airnix. Two OS setups for the same two machines."
	@echo
	@echo "NixOS (nix/):"
	@echo "  make nix-iso        build the NixOS installer ISO (via Podman)"
	@echo "  make nix-machine    one-time Podman machine setup"
	@echo "  make nix-fmt        nixpkgs-fmt every .nix file"
	@echo "  make nix-lock       regenerate flake.lock"
	@echo "  make nix-clean      remove the built ISO"
	@echo
	@echo "Arch (arch/):"
	@echo "  make arch-check     syntax-check scripts + validate the niri/noctalia configs"
	@echo "  make arch-iso       build the Arch ISO (needs an Arch host)"
	@echo "  make arch-iso-podman   build the Arch ISO in a container"
	@echo "  make arch-clean     remove archiso build artifacts"
	@echo
	@echo "Both:"
	@echo "  make check          run every check that works on this host"
	@echo
	@echo "Inside nix/ or arch/ the targets are unprefixed: 'make iso'."
	@echo "Flashing is deliberately not a target; see the README."
