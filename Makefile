MAKE_SUBPROJS="solidity frontend"

SOLIDITY_SOURCES=$(wildcard solidity/contracts/*.sol solidity/contracts/lib/*.sol solidity/contracts/sapphire/*.sol interfaces/*.sol)

REGTEST_LOCALNET_JSON=btcrelay/deployments/btc-regtest_sapphire-localnet.json

PYMOD=btcrelay

all: $(MAKE_SUBPROJS)
.PHONY: $(MAKE_SUBPROJS)

include common.mk

frontend:
	$(MAKE) -C "$@"

.PHONY: solidity
solidity: $(SOLIDITY_SOURCES)
	$(MAKE) -C "$@"
	touch "$@"

solidity-clean:
	$(MAKE) -C solidity clean

clean: python-clean
	@for PN in $(MAKE_SUBPROJS); do \
		$(MAKE) -C "$$PN" clean ; \
	done

python: python-mypy python-wheel

python-clean:
	rm -rf *.egg-info dist build .mypy_cache
	rm -rf "$(PYMOD)/__pycache__" "$(PYMOD)/deployments/__pycache__"

veryclean: clean
	rm -rf "$(dir $(SOLC))"
	rm -rf $(PYMOD)/deployments/*_sapphire-localnet.json $(PYMOD)/deployments/btc-regtest-*.json

python-wheel: python-clean solidity
	$(PYTHON) setup.py -q bdist_wheel

$(REGTEST_LOCALNET_JSON): solidity
	rm -f $@
	$(PYTHON) -m$(PYMOD) deploy -y --sapphire localnet --chain btc-regtest --loglevel debug

debug-btc: $(REGTEST_LOCALNET_JSON)
	$(PYTHON) -m$(PYMOD) fetchd --sapphire localnet --chain btc-regtest --loglevel debug

debug: solidity debug-btc

debug-release: solidity python-wheel
	$(PYTHON) dist/*.whl deploy -y --sapphire localnet --chain btc-testnet --loglevel info
	$(PYTHON) dist/*.whl fetchd --sapphire localnet --chain btc-testnet --loglevel info

python-mypy: python-clean
	$(PYTHON) -mmypy --check-untyped-defs $(PYMOD)

python-mypy-strict: python-clean
	$(PYTHON) -mmypy --strict $(PYMOD)
