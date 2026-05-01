PROFILE ?= dev-linux

.PHONY: bootstrap switch verify develop go fmt check

bootstrap:
	bash scripts/bootstrap-nix.sh

switch:
	bash scripts/apply.sh $(PROFILE)

verify:
	bash scripts/verify.sh

develop:
	nix develop

go:
	nix develop .#go

fmt:
	nix fmt

check:
	nix flake check
	