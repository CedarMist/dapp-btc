ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=$(ROOT_DIR)build
CONTRACTS_DIR=$(ROOT_DIR)contracts

all: $(BUILD_DIR)/BTCDeposit.bin

include $(ROOT_DIR)/../common.mk

$(BUILD_DIR)/BTCDeposit.bin: $(SOLC) $(wildcard $(CONTRACTS_DIR)/*.sol $(CONTRACTS_DIR)/lib/*.sol)
	rm -rf "$(dir $@)"
	mkdir -p "$(dir $@)"
	$(SOLC) -o "$(dir $@)" $(SOLC_OPTS) $(wildcard $(CONTRACTS_DIR)/*.sol)
	find "$(dir $@)" -name '*.bin' -size 0 | xargs rm  # Remove empty .bin files

clean:
	rm -rf $(BUILD_DIR)
