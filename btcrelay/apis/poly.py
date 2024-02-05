# SPDX-License-Identifier: Apache-2.0

from typing import Optional, TypedDict

from ..constants import BTC_CHAIN_T, DEFAULT_BTC_RPC_URLS
from .bitcoinrpc import BitcoinJsonRpc, BitcoinJsonRpc_getblock_t
from .mempoolspace import MempoolSpaceAPI


class PolyAPIError(RuntimeError):
    pass


class PolyAPI_BlockHeader(TypedDict):
    height: int
    time: int
    bits: int


class PolyAPI:
    """
    Use multiple underlying APIs to retrieve the info necessary for multiple
    bitcoin compatible chains. Some providers don't support mainnet, some only
    support Bitcoin or Doge etc. or don't support all methods (like getblock.io)
    """
    _chain:BTC_CHAIN_T
    _mempoolspace:Optional[MempoolSpaceAPI]
    _bitcoinrpc:BitcoinJsonRpc

    def __init__(self, chain:BTC_CHAIN_T, custom_btc_rpc_url:Optional[str]):
        self._chain = chain

        # Mempool.space only supports Bitcoin mainnet & testnet
        if chain in ('btc-mainnet', 'btc-testnet'):
            self._mempoolspace = MempoolSpaceAPI(chain)

        # Setup Bitcoin RPC node
        if not custom_btc_rpc_url:
            if chain in DEFAULT_BTC_RPC_URLS:
                btc_rpc_url = DEFAULT_BTC_RPC_URLS[chain]
            else:
                raise PolyAPIError(f'No Getblock.io JSON-RPC endpoint for chain: {chain}')
        else:
            btc_rpc_url = custom_btc_rpc_url

        self._bitcoinrpc = BitcoinJsonRpc(btc_rpc_url)

    def getheader(self, block_hash:str|bytes) -> BitcoinJsonRpc_getblock_t:
        return self._bitcoinrpc.getblockheader(block_hash)

    def height(self) -> int:
        return self._bitcoinrpc.getblockcount()

    def height2hash(self, height:int) -> bytes:
        return self._bitcoinrpc.getblockhash(height)
