import json
import struct
import hashlib
from urllib.request import urlopen
from typing import TypedDict, Optional, Literal, Any

from .constants import BTC_CHAIN_T
from .jsonrpc import jsonrpc


def sha256(s:bytes):
    return hashlib.sha256(s).digest()

def double_sha256(s:bytes):
    return sha256(sha256(s))


def merkle_build(hashes:list[bytes]):
    while len(hashes) > 1:
        size = len(hashes)
        hashes = [double_sha256(hashes[i] + hashes[min(i + 1, size - 1)])
                  for i in range(0, size, 2)]
    if hashes:
        return hashes[0]


def hex2revbytes(x:str):
    """Convert a hexadecimal encoded byte string, to bytes, then reversed"""
    # NOTE: hashes returned by JSON-RPC API are in reverse byte order
    return bytes.fromhex(x)[::-1]


def bytes2revhex(x:bytes):
    return x[::-1].hex()


# https://github.com/dcposch/silverportal/blob/7899cfee79a0358543141443c36e0a77701bcb45/packages/portal-marketmaker/src/index.js#L407
def hashserializedrawtx():
    pass

################################################################################


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


def serialize_header(block:BitcoinJsonRpc_getblock_t):
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


def parse_getblockheader_t(result:dict):
    result['hash'] = hex2revbytes(result['hash'])
    result['previousblockhash'] = hex2revbytes(result['previousblockhash'])
    result['merkleroot'] = hex2revbytes(result['merkleroot'])
    result['bits'] = int(result['bits'],16)
    result['chainwork'] = int.from_bytes(hex2revbytes(result['chainwork']))
    if result.get('nextblockhash',None) is not None:
        # XXX: not included when retrieved from getblock RPC?
        result['nextblockhash'] = hex2revbytes(result['nextblockhash'])


def parse_getblock_t(result:dict):
    parse_getblockheader_t(result)
    result['tx'] = [hex2revbytes(_) for _ in result['tx']]


class BitcoinJsonRpc_getchaintips_t(TypedDict):
    """
    https://github.com/thephez/dash/blob/master/src/rpc/blockchain.cpp#L1806
    """
    branchlen: int
    hash: str
    height: int
    status: Literal['invalid',
                    'headers-only',
                    'valid-headers',
                    'valid-fork',
                    'active',
                    'conflicting']


################################################################################


class BitcoinJsonRpc:
    def __init__(self, endpoint_url):
        self.endpoint_url = endpoint_url

    def _request(self, method:str, params:Optional[list[Any]]=None):
        return jsonrpc(self.endpoint_url, method, params)

    def getchaintips(self) -> list[BitcoinJsonRpc_getchaintips_t]:
        tips:list[BitcoinJsonRpc_getchaintips_t] = self._request('getchaintips')
        for row in tips:
            row['hash'] = hex2revbytes(row['hash'])
        return tips

    def uptime(self) -> int:
        return self._request('uptime')

    def getblockcount(self) -> int:
        return self._request('getblockcount')

    def getblockhash(self, height:int) -> bytes:
        return hex2revbytes(self._request('getblockhash', [height]))

    def getrawtransaction(self, txid:str, blockhash:Optional[str]=None) -> bytes:
        return self._request('getrawtransaction', [txid, False, blockhash])

    def getblockheader(self, blockhash:str|bytes) -> BitcoinJsonRpc_getblock_t:
        if isinstance(blockhash, bytes):
            blockhash = bytes2revhex(blockhash)
        verbosity = True
        result = self._request('getblockheader', [blockhash, verbosity])
        parse_getblockheader_t(result)
        return result

    def getblock(self, blockhash:str|bytes) -> BitcoinJsonRpc_getblock_t:
        if isinstance(blockhash, bytes):
            blockhash = bytes2revhex(blockhash)
        verbosity = 1  # includes tx hashes
        result = self._request('getblock', [blockhash, verbosity])
        parse_getblock_t(result)
        return result

    def getblockraw(self, blockhash:str) -> str:
        verbosity = 0  # returns raw hex encoded block
        return self._request('getblock', [blockhash, verbosity])


################################################################################


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
    scriptpubkey_type: str  # e.g. p2pkh, v0_p2wpkh, v1_p2tr, v0_p2wsh, p2sh
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

    def __init__(self, chain:Optional[BTC_CHAIN_T]=None):
        if not chain:
            chain = 'btc-mainnet'
        elif chain not in ['btc-mainnet', 'btc-testnet', 'btc-signet']:
            raise RuntimeError(f'Mempool.space unsupported chain: {chain}')
        self.chain = chain

    def _url(self, *args):
        url = ['https://mempool.space']
        if self.chain != 'btc-mainnet':
            url += [self.chain]
        url += ['api']
        return '/'.join(url + [str(_) for _ in args])

    def _request(self, *args, is_json=True):
        url = self._url(*args)
        with urlopen(url) as handle:
            if handle.status != 200:
                raise MempoolspaceError(url, handle.status)
            raw_response = handle.read()
            if is_json:
                return json.loads(raw_response)
            return raw_response.decode('utf-8')

    def address_utxos(self, address:str) -> list[MempoolSpace_UTXO]:
        return self._request('address', address, 'utxo')

    def block_transactions(self, blockhash:str) -> list[MempoolSpace_Transaction]:
        return self._request('block', blockhash, 'txs')

    def get_block_hash(self, height:int) -> str:
        return self._request('block-height', height, is_json=False)

    def get_block_header(self, blockhash:str) -> str:
        return self._request('block', blockhash, 'header', is_json=False)

    def tx_merkleproof(self, txid:str) -> MempoolSpace_MerkleProof:
        return self._request('tx', txid, 'merkle-proof')

    def tx_hex(self, txid:str) -> str:
        return self._request('tx', txid, 'hex', is_json=False)