import os
import typing
import logging
from typing import Literal, Tuple
from web3 import Web3

BTC_CHAIN_T = Literal['btc-mainnet', 'btc-testnet','btc-signet', 'ltc-mainnet', 'ltc-testnet', 'doge-mainnet', 'doge-testnet']
CHAIN_CHOICES: Tuple[BTC_CHAIN_T, ...] = typing.get_args(BTC_CHAIN_T)

SAPPHIRE_CHAIN_T = Literal['sapphire-mainnet', 'sapphire-testnet', 'sapphire-localnet']
SAPPHIRE_CHOICES: Tuple[SAPPHIRE_CHAIN_T, ...] = typing.get_args(SAPPHIRE_CHAIN_T)

DEFAULT_GAS_PRICE = Web3.to_wei(100, 'gwei')

DEFAULT_GETBLOCK_URLS: dict[BTC_CHAIN_T,str] = {
    'btc-mainnet': 'https://go.getblock.io/f8f103b600fb4a869de196e970c65fd1',
    'btc-testnet': 'https://go.getblock.io/818286a585854c5e9bdf73fdd560b49a',
    'ltc-mainnet': 'https://go.getblock.io/cc11923e83e241809b039d3e40c645fe',
    'doge-mainnet': 'https://go.getblock.io/1316968b250f4c85ae7b19220b5eb492'
}

DEFAULT_SAPPHIRE_RPC_URLS: dict[SAPPHIRE_CHAIN_T,str] = {
    'sapphire-mainnet': 'https://sapphire.oasis.io',
    'sapphire-localnet': 'http://127.0.0.1:8545',
    'sapphire-testnet': 'https://testnet.sapphire.oasis.dev'
}

DEFAULT_WALLET=os.getenv('BTCRELAY_WALLET', '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
DEFAULT_BTCRPC=os.getenv('BTCRELAY_BTCRPC', None)

# Other RPC providers:
# - https://www.allthatnode.com/
# - https://tatum.io/

# Address of BTCRelay contract
DEFAULT_BTCRELAY_ADDR=os.getenv('BTCRELAY_ADDR')

# Number of transactions to submit to relay per tx
DEFAULT_BATCH_COUNT=50

DEFAULT_SLEEP_TIME=60

LOGGER_LEVEL_NAMES_T = Literal['d', 'debug', 'i', 'info', 'w', 'warn', 'warning', 'e', 'error']

LOGGER_LEVELS: dict[LOGGER_LEVEL_NAMES_T,int] = {
    'debug': logging.DEBUG,
    'd': logging.DEBUG,
    'i': logging.INFO,
    'info': logging.INFO,
    'w': logging.WARNING,
    'warn': logging.WARN,
    'warning': logging.WARNING,
    'e': logging.ERROR,
    'error': logging.ERROR
}
