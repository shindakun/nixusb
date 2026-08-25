# Root dispatcher. The real build lives in nix/Makefile; this just forwards so
# `make iso` works from the repo root as well as from inside nix/.
#
# The arch/ side has no build step (it's install scripts + dotfiles you run on
# the target machine), so every target here is a Nix target.

.PHONY: iso fmt lock machine clean help

iso fmt lock machine clean help:
	@$(MAKE) -C nix $@
