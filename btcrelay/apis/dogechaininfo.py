# SPDX-License-Identifier: Apache-2.0

import json
from urllib.request import urlopen
from typing import Literal, TypedDict, Optional

from ..constants import BTC_CHAIN_T


class DogechainInfo_PrevOutput(TypedDict):
    hash: str
    pos: int


class DogechainInfo_Input(TypedDict):
    pos: int
    value: str
    address: str
    scriptSig: dict[Literal['hex','asm'],str]
    previous_output: DogechainInfo_PrevOutput


class DogechainInfo_Output(TypedDict):
    pos: int
    value: str
    address: str
    script: dict[Literal['hex'],str]
    spent: DogechainInfo_PrevOutput


class DogechainInfo_Transaction(TypedDict):
    hash: str
    confirmations: int
    size: int
    vsize: int
    weight: Optional[int]
    version: int
    locktime: int
    block_hash: str
    time: int
    inputs_n: int
    inputs_value: str
    inputs: list[DogechainInfo_Input]
    outputs_n: int
    outputs_value: str
    outputs: list[DogechainInfo_Output]
    fee: str
    price: str


class DogechainInfo_Unspent(TypedDict):
    tx_hash: str
    tx_output_n: int
    script: str
    address: str
    value: int
    confirmations: int
    tx_hex: str


class DogechainInfoError(RuntimeError):
    pass


class DogechainInfo_Response(TypedDict):
    unspent_outputs: list[DogechainInfo_Unspent]
    transaction: DogechainInfo_Transaction
    error: str
    success: int


class DogechainInfoAPI:
    BASE_URL = 'https://dogechain.info/api/v1'

    def _url(self, *args):
        return '/'.join([self.BASE_URL] + [str(_) for _ in args])

    def _request(self, *args):
        url = self._url(*args)
        with urlopen(url) as handle:
            if handle.status != 200:
                raise DogechainInfoError(url, handle.status)
            response: DogechainInfo_Response = json.load(handle)
            if response['success'] != 1:
                raise DogechainInfoError(response['error'])
            return response

    def __init__(self, chain:BTC_CHAIN_T):
        if chain != 'doge-mainnet':
            raise DogechainInfoError(f'Invalid chain {chain}')

    def unspent(self, address:str, page:int=1):
        return self._request('address', 'unspent', address, page)['unspent_outputs']

    def transaction(self, tx_hash:str):
        return self._request('transaction', tx_hash)['transaction']

