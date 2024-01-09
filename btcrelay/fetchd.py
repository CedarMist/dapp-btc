# SPDX-License-Identifier: Apache-2.0

import json
from time import sleep
from typing import Optional
from io import TextIOWrapper
from argparse import ArgumentParser, FileType

from web3 import Web3
from eth_typing import ChecksumAddress
from eth_utils.address import to_checksum_address

from .cmd import Cmd
from .contracts import ContractInfo
from .apis.bitcoinrpc import BitcoinJsonRpc_getblock_t
from .bitcoin import bytes2revhex
from .constants import (
    LOGGER,
    __LINE__,
    DEFAULT_BTCRELAY_ADDR,
    DEFAULT_SLEEP_TIME,
    DEFAULT_GAS_PRICE,
    DEFAULT_BATCH_COUNT
)


class CmdFetchd(Cmd):
    address: ChecksumAddress
    deploy_file: Optional[TextIOWrapper]
    batch_count: int

    @classmethod
    def setup(cls, parser:ArgumentParser):
        super().setup(parser)
        parser.add_argument('-f', '--deploy-file', metavar='path', type=FileType('r'),
                            help='Read BTCRelay contract address from a file')
        parser.add_argument('-c', '--batch-count', metavar='n', type=int,
                            default=DEFAULT_BATCH_COUNT,
                            help='Miximum number of blocks to submit per tx')
        parser.add_argument('address', nargs='?', metavar='0xBTCRelayAddress',
                            help='BTCRelay contract address (env: BTCRELAY_ADDR)',
                            default=DEFAULT_BTCRELAY_ADDR)

    def __call__(self):
        relay = self.dcim.contract_instance('BTCRelay', self.web3)
        getLatestBlockHeight = relay.functions.getLatestBlockHeight
        getBlockHash = relay.functions.getBlockHashReversed
        submit = relay.functions.submit

        while True:
            try:
                contractHeight: int = getLatestBlockHeight().call()
                contractHash: bytes = getBlockHash(contractHeight).call()
                btcHeight = self.poly.height()
                btcTipHash = self.poly.height2hash(btcHeight)

                LOGGER.debug('BTCRelay height %d (%s)',
                             contractHeight, bytes2revhex(contractHash))

                LOGGER.debug('BTC height %d (%s)',
                             btcHeight, bytes2revhex(btcTipHash))

                if contractHeight == btcHeight and contractHash == btcTipHash:
                    LOGGER.debug('No blocks to sync, sleeping %d seconds',
                                 DEFAULT_SLEEP_TIME)
                    sleep(DEFAULT_SLEEP_TIME)  # delay a few minutes
                    continue

                # Work backwards to findcommon block hash and height
                startHeight = contractHeight
                while True:
                    contractHash = getBlockHash(startHeight).call()
                    btcTipHash = self.poly.height2hash(startHeight)
                    if contractHash == btcTipHash:
                        startHeight += 1
                        break
                    startHeight -= 1

                LOGGER.debug('Need to sync %d blocks, %d to %d',
                             (btcHeight - startHeight) + 1,
                             startHeight, btcHeight)

                # Fetch missing/diverged blocks from RPC
                blocks: list[BitcoinJsonRpc_getblock_t] = []
                for i in range(startHeight, btcHeight + 1):
                    btcHash = self.poly.height2hash(i)
                    blocks.append(self.poly.getheader(btcHash))
                    LOGGER.debug('Adding block to sync: %d %s', i, bytes2revhex(btcHash))
                    if len(blocks) >= self.batch_count:
                        break

                # Submit blocks on-chain, and display cost
                txid = submit(blocks[0]['height'], blocks).transact({
                    'gasPrice': DEFAULT_GAS_PRICE
                })
                receipt = self.web3.eth.wait_for_transaction_receipt(txid)
                effectiveGasPrice = receipt.get('effectiveGasPrice', DEFAULT_GAS_PRICE)
                receiptCost = Web3.from_wei(receipt['gasUsed'] * effectiveGasPrice, 'ether')
                LOGGER.info('Submitted %d blocks, gas %d (cost %s) tx %s',
                            len(blocks), receipt['gasUsed'], receiptCost, receipt['transactionHash'].hex())

            except KeyboardInterrupt:
                break

        return 0
