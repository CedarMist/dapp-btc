SUBPROJS=lightclient token

SOLIDITY_SOURCES=$(wildcard lightclient/contracts/*.sol lightclient/contracts/lib/*.sol token/contracts/*.sol token/contracts/lib/*.sol interfaces/*.sol)

PYMOD=btcrelay

all: $(SUBPROJS)
.PHONY: $(SUBPROJS)

include common.mk

lightclient:
	$(MAKE) -C "$@"

token:
	$(MAKE) -C "$@"

clean: python-clean
	@for PN in $(SUBPROJS); do \
		$(MAKE) -C "$$PN" clean ; \
	done

python-clean:
	rm -rf *.egg-info dist build .mypy_cache
	rm -rf $(PYMOD)/__pycache__ $(PYMOD)/abi/__pycache__ $(PYMOD)/deployments/__pycache__

veryclean: clean
	rm -rf "$(dir $(SOLC))"

python-wheel: python-clean $(SUBPROJS)
	$(PYTHON) setup.py -q bdist_wheel

debug-btc:
	$(PYTHON) -m$(PYMOD) deploy -y --sapphire localnet --chain btc-testnet --loglevel debug
	$(PYTHON) -m$(PYMOD) fetchd --sapphire localnet --chain btc-testnet --loglevel debug

debug-ltc:
	$(PYTHON) -m$(PYMOD) deploy -y --sapphire localnet --chain ltc-mainnet --loglevel debug
	$(PYTHON) -m$(PYMOD) fetchd --sapphire localnet --chain ltc-mainnet --loglevel debug

debug-doge:
	$(PYTHON) -m$(PYMOD) deploy -y --sapphire localnet --chain doge-mainnet --loglevel debug
	$(PYTHON) -m$(PYMOD) fetchd --sapphire localnet --chain doge-mainnet --loglevel debug

debug: $(SUBPROJS) debug-btc

debug-release: $(SUBPROJS) python-wheel deployments
	rm -f $(LOCALNET_JSON)
	$(PYTHON) dist/*.whl deploy -y -f $(LOCALNET_JSON)
	$(PYTHON) dist/*.whl fetchd -f $(LOCALNET_JSON) -l debug

python-mypy: python-clean
	$(PYTHON) -mmypy --check-untyped-defs $(PYMOD)

python-mypy-strict: python-clean
	$(PYTHON) -mmypy --strict $(PYMOD)
