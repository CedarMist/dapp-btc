# SPDX-License-Identifier: Apache-2.0

import struct
from typing import Any, TypedDict, Optional, Literal, cast

from .jsonrpc import jsonrpc
from ..bitcoin import double_sha256, merkle_build, hex2revbytes, bytes2revhex
from ..constants import DEFAULT_BTC_RPC_URLS

def regtest(method, *args):
    return jsonrpc(DEFAULT_BTC_RPC_URLS['btc-regtest'], method, args)

JSON_ENCODABLE_PRIMITIVE = str | int | bytes | None
JSON_ENCODABLE = JSON_ENCODABLE_PRIMITIVE | dict[str|int,JSON_ENCODABLE_PRIMITIVE] | list[JSON_ENCODABLE_PRIMITIVE]

class BitcoinJsonRpc_getblockheader_t(TypedDict):
    bits: str
    chainwork: int
    confirmations: str
    difficulty: float
    hash: bytes
    height: int
    mediantime: int
    merkleroot: bytes
    nTx: int
    nextblockhash: Optional[bytes]
    nonce: int
    previousblockhash: bytes
    time: int
    version: int
    versionHex: str


class BitcoinJsonRpc_getblock_t(BitcoinJsonRpc_getblockheader_t):
    size: int
    strippedsize: int
    tx: list[bytes]
    weight: int


def serialize_header(block:BitcoinJsonRpc_getblock_t) -> bytes:
    o = struct.pack('<I32s32sIII',
                    block['version'],
                    block['previousblockhash'],
                    block['merkleroot'],
                    block['time'],
                    block['bits'],
                    block['nonce'])
    h = double_sha256(o)
    mr = merkle_build(block['tx'])
    assert mr == block['merkleroot']
    assert h == block['hash']
    return o


def parse_getblockheader_t(result:dict[str,Any]) -> None:
    result['hash'] = hex2revbytes(result['hash'])
    result['previousblockhash'] = hex2revbytes(result['previousblockhash'])
    result['merkleroot'] = hex2revbytes(result['merkleroot'])
    result['bits'] = int(result['bits'],16)
    result['chainwork'] = int.from_bytes(hex2revbytes(result['chainwork']))
    if result.get('nextblockhash',None) is not None:
        # XXX: not included when retrieved from getblock RPC?
        result['nextblockhash'] = hex2revbytes(result['nextblockhash'])


def parse_getblock_t(result:dict[str,Any]) -> None:
    parse_getblockheader_t(result)
    result['tx'] = [hex2revbytes(_) for _ in result['tx']]


class BitcoinJsonRpc_getchaintips_t(TypedDict):
    """
    https://github.com/thephez/dash/blob/master/src/rpc/blockchain.cpp#L1806
    """
    branchlen: int
    hash: bytes|str
    height: int
    status: Literal['invalid',
                    'headers-only',
                    'valid-headers',
                    'valid-fork',
                    'active',
                    'conflicting']


class BitcoinJsonRpc:
    def __init__(self, endpoint_url:str):
        self.endpoint_url = endpoint_url

    def _request(self, method:str, params:Optional[list[JSON_ENCODABLE]]=None) -> Any:
        return jsonrpc(self.endpoint_url, method, params)

    def getchaintips(self) -> list[BitcoinJsonRpc_getchaintips_t]:
        tips:list[BitcoinJsonRpc_getchaintips_t] = self._request('getchaintips')
        for row in tips:
            row['hash'] = hex2revbytes(row['hash'])
        return tips

    def uptime(self) -> int:
        return cast(int, self._request('uptime'))

    def getblockcount(self) -> int:
        return cast(int, self._request('getblockcount'))

    def gettxout(self, txid:str|bytes, out_idx:int):
        if isinstance(txid, bytes):
            txid = bytes2revhex(txid)
        return self._request('gettxout', [txid, out_idx])

    def gettxoutproof(self, txids:list[str|bytes]):
        txids = [bytes2revhex(_) for _ in txids]
        return self._request('gettxoutproof', [txids])

    def getblockhash(self, height:int) -> bytes:
        return hex2revbytes(self._request('getblockhash', [height]))

    def getrawtransaction(self, txid:str, blockhash:Optional[str]=None) -> bytes:
        return bytes.fromhex(self._request('getrawtransaction', [txid, False, blockhash]))

    def getblockheader(self, blockhash:str|bytes) -> BitcoinJsonRpc_getblock_t:
        if isinstance(blockhash, bytes):
            blockhash = bytes2revhex(blockhash)
        verbosity = True
        result = self._request('getblockheader', [blockhash, verbosity])
        parse_getblockheader_t(result)
        return cast(BitcoinJsonRpc_getblock_t, result)

    def getblock(self, blockhash:str|bytes, verbose=False) -> BitcoinJsonRpc_getblock_t:
        if isinstance(blockhash, bytes):
            blockhash = bytes2revhex(blockhash)
        verbosity = 1  # includes tx hashes
        if verbose:
            verbosity = 2
        result = self._request('getblock', [blockhash, verbosity])
        parse_getblock_t(result)
        return cast(BitcoinJsonRpc_getblock_t, result)

    def getblockraw(self, blockhash:str) -> str:
        verbosity = 0  # returns raw hex encoded block
        return cast(str, self._request('getblock', [blockhash, verbosity]))
