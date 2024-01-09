# SPDX-License-Identifier: Apache-2.0

from typing import Optional, TypedDict

from ..constants import BTC_CHAIN_T, DEFAULT_GETBLOCK_URLS, LOGGER
from .bitcoinrpc import BitcoinJsonRpc
from .dogechaininfo import DogechainInfoAPI
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
    _dogeinfo:Optional[DogechainInfoAPI]
    _bitcoinrpc:BitcoinJsonRpc

    def __init__(self, chain:BTC_CHAIN_T, custom_btc_rpc_url:Optional[str]):
        self._chain = chain

        # Mempool.space only supports Bitcoin mainnet & testnet
        if chain in ('btc-mainnet', 'btc-testnet'):
            self._mempoolspace = MempoolSpaceAPI(chain)

        # Dogechain.info only works for mainnet
        if chain == 'doge-mainnet':
            self._dogeinfo = DogechainInfoAPI(chain)

        # Setup Bitcoin RPC node
        if not custom_btc_rpc_url:
            if chain in DEFAULT_GETBLOCK_URLS:
                btc_rpc_url = DEFAULT_GETBLOCK_URLS[chain]
            else:
                raise PolyAPIError(f'No Getblock.io JSON-RPC endpoint for chain: {chain}')
        else:
            btc_rpc_url = custom_btc_rpc_url

        self._bitcoinrpc = BitcoinJsonRpc(btc_rpc_url)

        LOGGER.debug('%s node.uptime:%.02f url:%s',
                     self._chain,
                     self._bitcoinrpc.uptime() / 60 / 60 / 24,
                     btc_rpc_url)

    def getheader(self, block_hash:str):
        return self._bitcoinrpc.getblockheader(block_hash)

    def height(self) -> int:
        return self._bitcoinrpc.getblockcount()

    def height2hash(self, height:int) -> bytes:
        return self._bitcoinrpc.getblockhash(height)
