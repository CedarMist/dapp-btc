ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=$(ROOT_DIR)build
CONTRACTS_DIR=$(ROOT_DIR)contracts

all: $(BUILD_DIR)/BTCRelay.bin

include $(ROOT_DIR)/../common.mk

$(BUILD_DIR)/BTCRelay.bin: $(SOLC) $(wildcard $(CONTRACTS_DIR)/*.sol) $(wildcard $(CONTRACTS_DIR)/lib/*.sol)
	rm -rf "$(dir $@)"
	mkdir -p "$(dir $@)"
	$(SOLC) -o "$(dir $@)" $(SOLC_OPTS) $(wildcard $(CONTRACTS_DIR)/*.sol)
	ls -la "$(dir $@)"

clean:
	rm -rf $(BUILD_DIR)
