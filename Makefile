MAKE_SUBPROJS="solidity frontend"

SOLIDITY_SOURCES=$(wildcard lightclient/contracts/*.sol lightclient/contracts/lib/*.sol token/contracts/*.sol token/contracts/lib/*.sol interfaces/*.sol)

PYMOD=btcrelay

all: $(MAKE_SUBPROJS)
.PHONY: $(MAKE_SUBPROJS)

include common.mk

frontend:
	$(MAKE) -C "$@"

solidity:
	$(MAKE) -C "$@"

clean: python-clean
	@for PN in $(MAKE_SUBPROJS); do \
		$(MAKE) -C "$$PN" clean ; \
	done

python: python-mypy python-wheel

python-clean:
	rm -rf *.egg-info dist build .mypy_cache
	rm -rf $(PYMOD)/__pycache__ $(PYMOD)/deployments/__pycache__

veryclean: clean
	rm -rf "$(dir $(SOLC))"

python-wheel: python-clean solidity
	$(PYTHON) setup.py -q bdist_wheel

debug-btc:
	$(PYTHON) -m$(PYMOD) deploy -y --sapphire localnet --chain btc-testnet --loglevel debug
	$(PYTHON) -m$(PYMOD) fetchd --sapphire localnet --chain btc-testnet --loglevel debug

debug: solidity debug-btc

debug-release: solidity python-wheel
	#$(PYTHON) dist/*.whl deploy -y --sapphire localnet --chain btc-testnet --loglevel debug
	$(PYTHON) dist/*.whl fetchd --sapphire localnet --chain btc-testnet --loglevel debug

python-mypy: python-clean
	$(PYTHON) -mmypy --check-untyped-defs $(PYMOD)

python-mypy-strict: python-clean
	$(PYTHON) -mmypy --strict $(PYMOD)
