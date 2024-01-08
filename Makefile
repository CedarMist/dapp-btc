SUBPROJS=lightclient token

SOLIDITY_SOURCES=$(wildcard lightclient/contracts/*.sol lightclient/contracts/lib/*.sol token/contracts/*.sol token/contracts/lib/*.sol interfaces/*.sol)

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
	rm -rf btcrelay/__pycache__ btcrelay/abi/__pycache__

veryclean: clean
	rm -rf "$(dir $(SOLC))"

python-wheel: python-clean $(SUBPROJS)
	$(PYTHON) setup.py -q bdist_wheel

BTC_TESTNET_SAPPHIRE_LOCALNET_JSON=btcrelay/deployments/btc-testnet.sapphire-localnet.json

$(dir $(LOCALNET_JSON)):
	mkdir -p $@

$(LOCALNET_JSON): $(dir $(LOCALNET_JSON)) $(SOLIDITY_SOURCES)
	$(PYTHON) -mbtcrelay deploy -y -f $(LOCALNET_JSON) -l debug

debug-fetchd: $(LOCALNET_JSON)
	$(PYTHON) -mbtcrelay fetchd -f $(LOCALNET_JSON) -l debug

debug: $(SUBPROJS) $(LOCALNET_JSON)	debug-fetchd

debug-release: $(SUBPROJS) python-wheel deployments
	rm -f $(LOCALNET_JSON)
	$(PYTHON) dist/*.whl deploy -y -f $(LOCALNET_JSON)
	$(PYTHON) dist/*.whl fetchd -f $(LOCALNET_JSON) -l debug

python-mypy:
	$(PYTHON) -mmypy --check-untyped-defs btcrelay
