COMMON_ROOT_DIR:=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))

PYTHON ?= python3

SOLC_PLAT?=linux-amd64
SOLC_VER?=v0.8.23
SOLC_COMMIT?=f704f362
SOLC_URL?=https://binaries.soliditylang.org/$(SOLC_PLAT)/solc-$(SOLC_PLAT)-$(SOLC_VER)%2Bcommit.$(SOLC_COMMIT)
SOLC?=$(COMMON_ROOT_DIR)bin/solc
SOLC_OPTS=--metadata --base-path $(COMMON_ROOT_DIR) --include-path $(COMMON_ROOT_DIR)interfaces --metadata-literal --abi --bin --overwrite --optimize --via-ir # --optimize-runs 4294967295

$(SOLC):
	mkdir -p "$(dir $(SOLC))"
	wget --quiet -O "$@" "$(SOLC_URL)"
	chmod 755 "$@"
