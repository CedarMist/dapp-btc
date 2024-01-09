# SPDX-License-Identifier: Apache-2.0

import json
from urllib.request import urlopen
from typing import Any, TypedDict, Literal, Optional

from ..constants import BTC_CHAIN_T

class MempoolSpace_UTXOStatus(TypedDict):
    confirmed: bool
    block_height: int
    block_hash: str
    block_time: int

class MempoolSpace_UTXO(TypedDict):
    txid: str
    vout: int
    status: MempoolSpace_UTXOStatus
    value: int

class MempoolSpace_MerkleProof(TypedDict):
    block_height: int
    merkle: list[str]
    pos: int

class MempoolSpace_TxVout(TypedDict):
    scriptpubkey: str
    scriptpubkey_asm: str   # disassembled script
    scriptpubkey_type: Literal['p2sh', 'p2pkh']  # e.g. p2pkh, v0_p2wpkh, v1_p2tr, v0_p2wsh, p2sh
    scriptpubkey_address: str
    value: int

class MempoolSpace_TxVin(TypedDict):
    txid: str
    vout: int
    prevout: Optional[MempoolSpace_TxVout]
    scriptsig: str
    scriptsig_asm: str
    witness: list[str]
    is_coinbase: Optional[bool]
    sequence: int
    inner_witnessscript_asm: Optional[str]

class MempoolSpace_Transaction(TypedDict):
    txid: str
    version: int
    locktime: int
    vin: list[MempoolSpace_TxVin]
    vout: list[MempoolSpace_TxVout]
    size: int
    weight: int
    sigops: int
    fee: int
    status: MempoolSpace_UTXOStatus


class MempoolspaceError(RuntimeError):
    pass


class MempoolSpaceAPI:
    """
    See: https://mempool.space/docs/api/rest
    One of the few APIs which doesn't suck and is free
    """
    chain: BTC_CHAIN_T

    def __init__(self, chain:BTC_CHAIN_T):
        if chain not in ['btc-mainnet', 'btc-testnet', 'btc-signet']:
            raise MempoolspaceError(f'Mempool.space unsupported chain: {chain}')
        self.chain = chain

    def _url(self, *args:str|int) -> str:
        url = ['https://mempool.space']
        if self.chain != 'btc-mainnet':
            url += [self.chain.replace('btc-', '')]
        url += ['api']
        return '/'.join(url + [str(_) for _ in args])

    def _request_json(self, *args:str|int) -> Any:
        return json.loads(self._request_bytes(*args))

    def _request_str(self, *args:str|int) -> str:
        return self._request_bytes(*args).decode('utf-8')

    def _request_bytes(self, *args:str|int) -> bytes:
        url = self._url(*args)
        with urlopen(url) as handle:
            if handle.status != 200:
                raise MempoolspaceError(url, handle.status)
            return handle.read()

    def address_utxos(self, address:str) -> list[MempoolSpace_UTXO]:
        return self._request_json('address', address, 'utxo')

    def block_transactions(self, blockhash:str) -> list[MempoolSpace_Transaction]:
        return self._request_json('block', blockhash, 'txs')

    def get_block_hash(self, height:int) -> str:
        return self._request_str('block-height', height)

    def get_block_header(self, blockhash:str) -> str:
        return self._request_str('block', blockhash, 'header')

    def tx_merkleproof(self, txid:str) -> MempoolSpace_MerkleProof:
        return self._request_json('tx', txid, 'merkle-proof')

    def tx_hex(self, txid:str) -> str:
        return self._request_str('tx', txid, 'hex')

