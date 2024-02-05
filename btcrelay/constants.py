# SPDX-License-Identifier: Apache-2.0

import os
import sys
import typing
import logging
import enum
from typing import Literal, Tuple
from web3 import Web3

class LineImpl(object):
    def __call__(self) -> int:
        try:
            raise Exception
        except:
            if (ei := sys.exc_info()[2]) is not None:
                if (tb_frame := ei.tb_frame) is not None:
                    if (f_back := tb_frame.f_back) is not None:
                        return f_back.f_lineno
            raise RuntimeError('Cannot get lineno from traceback')

    def __repr__(self) -> str:
        return str(self())

    def __str__(self) -> str:
        return self.__repr__()

__LINE__ = LineImpl()


logging.basicConfig(format='# %(asctime)s %(module)s %(levelname)s:  %(message)s', level=logging.INFO, handlers=[logging.StreamHandler(sys.stderr)])
LOGGER = logging.getLogger(__name__)


BTC_CHAIN_T = Literal['btc-mainnet', 'btc-testnet', 'btc-regtest']
CHAIN_CHOICES: Tuple[BTC_CHAIN_T, ...] = typing.get_args(BTC_CHAIN_T)
DEFAULT_BTC_RPC_URLS: dict[BTC_CHAIN_T,str] = {
    'btc-mainnet': 'https://go.getblock.io/0012d6e2a94942d7acefe23d4ffcb127',
    'btc-testnet': 'https://go.getblock.io/dc53faa553904edab52312240d6f8a0e',
    'btc-regtest': ('http://127.0.0.1:18443', ('user','pass'))
}

SAPPHIRE_CHAIN_T = Literal['mainnet', 'testnet', 'localnet']
SAPPHIRE_CHOICES: Tuple[SAPPHIRE_CHAIN_T, ...] = typing.get_args(SAPPHIRE_CHAIN_T)
SAPPHIRE_CHAINS_BY_CHAINID: dict[int,SAPPHIRE_CHAIN_T] = {
    0x5afe: 'mainnet',
    0x5aff: 'testnet',
    0x5afd: 'localnet'
}

DEFAULT_GAS_PRICE = Web3.to_wei(100, 'gwei')

DEFAULT_SAPPHIRE_RPC_URLS: dict[SAPPHIRE_CHAIN_T,str] = {
    'mainnet': 'https://sapphire.oasis.io',
    'testnet': 'https://testnet.sapphire.oasis.dev',
    'localnet': 'http://127.0.0.1:8545',
}

CONTRACT_NAME_T = Literal['BTCRelay', 'TxVerifier', 'BTCDeposit', 'Helper', 'LiquidBTC', 'Multicall3']
CONTRACT_NAMES: Tuple[CONTRACT_NAME_T, ...] = typing.get_args(CONTRACT_NAME_T)

class ContractName(enum.StrEnum):
    BTCRelay = 'BTCRelay'
    TxVerifier = 'TxVerifier'
    BTCDeposit = 'BTCDeposit'
    Helper = 'Helper'
    LiquidBTC = 'LiquidBTC'
    Multicall3 = 'Multicall3'
    def __str__(self) -> str:
        return self.value

DEFAULT_WALLET=os.getenv('BTCRELAY_WALLET', '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
DEFAULT_BTCRPC=os.getenv('BTCRELAY_BTCRPC', None)

# Other RPC providers ?
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
