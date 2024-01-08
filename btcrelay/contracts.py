import json
import enum
from enum import StrEnum
from importlib import resources
from typing import Optional, TypedDict, Type
from eth_typing import Address, ChecksumAddress

from web3 import Web3
from web3.contract import Contract
from web3.types import TxParams, TxReceipt, ChecksumAddress

from .constants import SAPPHIRE_CHAIN_T

# Always use resources API for files, so it works running directly from wheels
ABI_DIR = resources.files(__package__ + '.abi')


SAPPHIRE_CHAINS_BY_CHAINID: dict[int,SAPPHIRE_CHAIN_T] = {
    0x5afe: 'sapphire-mainnet',
    0x5aff: 'sapphire-testnet',
    0x5afd: 'sapphire-localnet'
}


def chain_name(chain_id:int):
    return SAPPHIRE_CHAINS_BY_CHAINID.get(chain_id, 'sapphire-unknown')


def contract_meta(name:str) -> dict:
    output = json.loads(ABI_DIR.joinpath(f'{name}_meta.json').read_text())['output']
    try:
        output['bytecode'] = bytes.fromhex(ABI_DIR.joinpath(f'{name}.bin').read_text())
    except FileNotFoundError:
        pass  # Silently ignore if bytecode file doesn't exist
    return output


def contract_factory(name:str, w3: Web3) -> Type[Contract]:
    meta = contract_meta(name)
    return w3.eth.contract(abi=meta['abi'], bytecode=meta.get('bytecode'))


def contract_instance(name:str, w3: Web3, address:Address|ChecksumAddress) -> Contract:
    meta = contract_meta(name)
    return w3.eth.contract(address, abi=meta['abi'])


@enum.unique
class ContractChoice(StrEnum):
    BTCRelay = 'BTCRelay'
    BTCDeposit = 'BTCDeposit'
    BtcTxVerifier = 'BtcTxVerifier'
    LiquidBTC = 'LiquidBTC'
    def __str__(self):
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
    constructor_args: list
    account_address: str
    account_nonce: int
    deployed: Optional[DeployedInfo]
