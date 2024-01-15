# SPDX-License-Identifier: Apache-2.0

import os
import sys
import typing
import logging
import enum
from typing import Literal, Tuple
from web3 import Web3

class LineImpl(object):
    def __repr__(self) -> str:
        try:
            raise Exception
        except:
            return str(sys.exc_info()[2].tb_frame.f_back.f_lineno)  # type: ignore

__LINE__ = LineImpl()


logging.basicConfig(format='# %(asctime)s %(module)s %(levelname)s:  %(message)s', level=logging.INFO, handlers=[logging.StreamHandler(sys.stderr)])
LOGGER = logging.getLogger(__name__)


BTC_CHAIN_T = Literal['btc-mainnet', 'btc-testnet']
CHAIN_CHOICES: Tuple[BTC_CHAIN_T, ...] = typing.get_args(BTC_CHAIN_T)


SAPPHIRE_CHAIN_T = Literal['mainnet', 'testnet', 'localnet']
SAPPHIRE_CHOICES: Tuple[SAPPHIRE_CHAIN_T, ...] = typing.get_args(SAPPHIRE_CHAIN_T)
SAPPHIRE_CHAINS_BY_CHAINID: dict[int,SAPPHIRE_CHAIN_T] = {
    0x5afe: 'mainnet',
    0x5aff: 'testnet',
    0x5afd: 'localnet'
}

DEFAULT_GAS_PRICE = Web3.to_wei(100, 'gwei')

DEFAULT_GETBLOCK_URLS: dict[BTC_CHAIN_T,str] = {
    'btc-mainnet': 'https://go.getblock.io/f8f103b600fb4a869de196e970c65fd1',
    'btc-testnet': 'https://go.getblock.io/818286a585854c5e9bdf73fdd560b49a',
}

DEFAULT_SAPPHIRE_RPC_URLS: dict[SAPPHIRE_CHAIN_T,str] = {
    'mainnet': 'https://sapphire.oasis.io',
    'testnet': 'https://testnet.sapphire.oasis.dev',
    'localnet': 'http://127.0.0.1:8545',
}

CONTRACT_NAME_T = Literal['BTCRelay', 'TxVerifier', 'BTCDeposit', 'Helper', 'LiquidBTC']
CONTRACT_NAMES: Tuple[CONTRACT_NAME_T, ...] = typing.get_args(CONTRACT_NAME_T)

class ContractName(enum.StrEnum):
    BTCRelay = 'BTCRelay'
    TxVerifier = 'TxVerifier'
    BTCDeposit = 'BTCDeposit'
    Helper = 'Helper'
    LiquidBTC = 'LiquidBTC'
    def __str__(self) -> str:
        return self.value

DEFAULT_WALLET=os.getenv('BTCRELAY_WALLET', '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
DEFAULT_BTCRPC=os.getenv('BTCRELAY_BTCRPC', None)

# Other RPC providers:
# - https://www.allthatnode.com/
# - https://tatum.io/

# Address of BTCRelay contract
DEFAULT_BTCRELAY_ADDR=os.getenv('BTCRELAY_ADDR')

# Number of transactions to submit to relay per tx
DEFAULT_BATCH_COUNT=5

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
