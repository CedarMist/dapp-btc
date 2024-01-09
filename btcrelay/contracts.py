# SPDX-License-Identifier: Apache-2.0

from importlib.abc import Traversable
import json
import enum
from enum import StrEnum
from importlib import resources
from typing import Optional, TypedDict, Type, Literal, Any

from hexbytes import HexBytes
from eth_typing import Address, ChecksumAddress

from web3 import Web3
from web3.datastructures import AttributeDict
from web3.contract.contract import Contract
from web3.types import TxParams, TxReceipt

from .constants import SAPPHIRE_CHAIN_T, BTC_CHAIN_T, CONTRACT_NAME_T, SAPPHIRE_CHAINS_BY_CHAINID, LOGGER

# Always use resources API for files, so it works run directly from .whl file
ABI_DIR = resources.files(__package__ + '.abi')

DEPLOYMENTS_DIR = resources.files(__package__ + '.deployments')


def sapphire_chain_name(chain_id:int) -> str:
    return 'sapphire-' + SAPPHIRE_CHAINS_BY_CHAINID.get(chain_id, 'unknown')


@enum.unique
class ContractChoice(StrEnum):
    LTCRelay = 'LTCRelay'
    DogeRelay = 'DogeRelay'
    BTCRelay = 'BTCRelay'
    BTCDeposit = 'BTCDeposit'
    BtcTxVerifier = 'BtcTxVerifier'
    LiquidBTC = 'LiquidBTC'
    def __str__(self) -> str:
        return self.value


class DeployedInfo(TypedDict):
    tx_id: str
    time_start: int|float
    time_end: int|float
    receipt: TxReceipt
    effective_gas_price: int


class ContractInfo(TypedDict):
    tx: TxParams
    max_fee: int
    expected_address: ChecksumAddress
    constructor_args: list[Any]
    account_address: ChecksumAddress
    account_nonce: int
    deployed: Optional[DeployedInfo]


class CompilerMeta(TypedDict):
    compiler: dict[Literal['version'],str]
    language: Literal['Solidity']
    output: dict[Literal['abi','bytecode'],Any]
    settings: dict[str,Any]
    sources: dict[str,str]
    version: int


class Encoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, HexBytes):
            return o.hex()
        if isinstance(o, bytes):
            return '0x' + o.hex()
        if isinstance(o, AttributeDict):
            return o.__dict__
        return super().default(o)


class DeployedContractInfoManager:
    """
    Information about deployed contracts is stored in the 'deployments' subpkg
    However, during development and deployment it can also be updated
    Deployments are specific to a chain and sapphire network (e.g. testnet, mainnet)
    """
    _data: dict[CONTRACT_NAME_T,ContractInfo]
    _chain: BTC_CHAIN_T
    _sapphire: SAPPHIRE_CHAIN_T

    def __init__(self, chain:BTC_CHAIN_T, sapphire:SAPPHIRE_CHAIN_T):
        self._chain = chain
        self._sapphire = sapphire
        self.load()

    def _deployment_file(self) -> Traversable:
        return DEPLOYMENTS_DIR.joinpath(f'{self._chain}.sapphire-{self._sapphire}.json')

    def token_name(self) -> CONTRACT_NAME_T:
        if self._chain.startswith('btc-'):
            return 'LiquidBTC'
        elif self._chain.startswith('doge-'):
            return 'LiquidDOGE'
        elif self._chain.startswith('ltc-'):
            return 'LiquidLTC'
        else:
            raise RuntimeError(f'Unknown liquid token name for chain! {self._chain}')

    def relay_name(self) -> CONTRACT_NAME_T:
        if self._chain.startswith('btc-'):
            return 'BTCRelay'
        elif self._chain.startswith('doge-'):
            return 'DogeRelay'
        elif self._chain.startswith('ltc-'):
            return 'LTCRelay'
        else:
            raise RuntimeError(f'Unknown relay name for chain! {self._chain}')

    def load(self) -> dict[CONTRACT_NAME_T,ContractInfo]:
        fn = self._deployment_file()
        try:
            with fn.open('r') as handle:
                self._data = json.load(handle)
        except:
            self._data = {}
        if len(self._data):
            LOGGER.debug('Loaded previous deployment info for %s from %s',
                         ','.join(self._data.keys()), fn)
        return self._data

    def update(self, cn:CONTRACT_NAME_T, info:ContractInfo) -> None:
        self._data[cn] = info
        with self._deployment_file().open('w') as handle:
            json.dump(self._data, handle, cls=Encoder, indent=4)

    def contract_meta(self, name:str) -> dict[Literal['abi', 'bytecode'], Any]:
        data:CompilerMeta = json.loads(ABI_DIR.joinpath(f'{name}_meta.json').read_text())
        output = data['output']
        try:
            output['bytecode'] = bytes.fromhex(ABI_DIR.joinpath(f'{name}.bin').read_text())
        except FileNotFoundError:
            pass  # Silently ignore if bytecode file doesn't exist
        return output

    def contract_factory(self, name:str, w3: Web3) -> Type[Contract]:
        meta = self.contract_meta(name)
        return w3.eth.contract(abi=meta['abi'], bytecode=meta.get('bytecode'))

    def contract_instance(self, name:CONTRACT_NAME_T, w3: Web3, address:Optional[ChecksumAddress]=None) -> Contract:
        if address is None:
            address = self._data[name]['expected_address']
        meta = self.contract_meta(name)
        return w3.eth.contract(address, abi=meta['abi'])
