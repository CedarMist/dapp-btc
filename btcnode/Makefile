BTC_VERSION=26.0
BTC_PLATFORM?=x86_64-linux-gnu
BTC_DIR=./bitcoin-$(BTC_VERSION)
BTC_BINARCHIVE=bitcoin-$(BTC_VERSION)-$(BTC_PLATFORM).tar.gz
BTC_URL=https://bitcoincore.org/bin/bitcoin-core-$(BTC_VERSION)/$(BTC_BINARCHIVE)
BTC_RPCAUTH=-rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpcuser=user -rpcpassword=pass -upnp=0
BTC_FALLBACKFEE=0.000001
BTCD_ARGS=--chain=regtest -datadir=data -port=18444 -txindex -discover=0 -nodnsseed -listenonion=0 -fallbackfee=$(BTC_FALLBACKFEE) $(BTC_RPCAUTH)
BTC_CLI=$(BTC_DIR)/bin/bitcoin-cli
CLI=$(BTC_CLI) $(BTC_RPCAUTH) -regtest

all: run

$(BTC_DIR): $(BTC_BINARCHIVE)
	if [ ! -d "$@" ]; then \
		tar -xf "$<" ; \
	fi

$(BTC_CLI): $(BTC_DIR)

$(BTC_BINARCHIVE):
	wget --quiet -O "$@" "$(BTC_URL)"

.PHONY:run
run: $(BTC_DIR)
	rm -rf data && mkdir data
	$(BTC_DIR)/bin/bitcoind $(BTCD_ARGS)

clean:
	rm -rf $(BTC_DIR) $(BTC_BINARCHIVE) data

qt: $(BTC_DIR)
	rm -rf data-client && mkdir -p data-client
	$(BTC_DIR)/bin/bitcoin-qt -regtest -datadir=data-client -rpcuser=user -rpcpassword=pass -listen=0 -addnode=127.0.0.1:18444 -fallbackfee=$(BTC_FALLBACKFEE)

tick:
	PYTHONPATH=.. python3 tick.py

fund:
	PYTHONPATH=.. python3 fund.py

getbalance: $(BTC_CLI)
	$(CLI) $@
