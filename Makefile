.DEFAULT_GOAL := build

BINARY := console
GOBIN ?= $(shell go env GOPATH)/bin

.PHONY: build test clean guard-gobin

guard-gobin:
	@test -n "$(strip $(GOBIN))" || { echo "the 'GOBIN' path is empty" >&2; exit 1; }
	@test "$(abspath $(GOBIN))" != "/" || { echo "the 'GOBIN' path resolves to '/'" >&2; exit 1; }

# build the binary. console has no frontend, so the build is a plain go install.
build: guard-gobin
	GOBIN="$(GOBIN)" go install ./...

# the ordinary repository gate.
test:
	go test ./... -count=1
	go vet ./...

clean: guard-gobin
	go clean ./...
	rm -f -- "$(GOBIN)/$(BINARY)"
