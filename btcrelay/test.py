import os
import sys
import json
import random
from typing import Optional
from argparse import ArgumentParser

from bitcoinutils.transactions import Transaction
from bitcoinutils.keys import P2pkhAddress, P2shAddress

from .cmd import Cmd, LOGGER, __LINE__
from .constants import DEFAULT_GAS_PRICE
from .bitcoin import MempoolSpace_Transaction, double_sha256, sha256
from .contracts import ContractChoice, ContractInfo, contract_instance


def test_BtTxVerifier(self:'CmdTest', contract_info:dict[str,ContractInfo]):
    BtcTxVerifier = contract_instance('BtcTxVerifier', self.web3, contract_info['BtcTxVerifier']['expected_address'])
    BTCRelay = contract_instance('BTCRelay', self.web3, contract_info['BTCRelay']['expected_address'])
    height:int = BTCRelay.functions.getLatestBlockHeight().call()
    relay_hash = BTCRelay.functions.getBlockHash(height).call().hex()
    blockhash = self.mempool_space.get_block_hash(height)
    if blockhash != relay_hash:
        raise RuntimeError(f'BTCRelay block hash mismatch, BTCRelay:{relay_hash} Mempool.space:{blockhash}')
    blockheader = self.mempool_space.get_block_header(blockhash)

    transactions = self.mempool_space.block_transactions(blockhash)

    # Select random P2SH & P2PKH transactions from the block
    p2sh_tx: Optional[tuple[int,MempoolSpace_Transaction,int]] = None
    p2pkh_tx: Optional[tuple[int,MempoolSpace_Transaction,int]] = None
    while not p2sh_tx or not p2pkh_tx:
        tx_idx = random.randint(0, len(transactions)-1)
        tx = transactions[tx_idx]
        # Ignore coinbase transactions, bitcoinutils gets messed up on them!
        if tx['vin'][0]['is_coinbase']:
            continue
        for i, tx_out in enumerate(tx['vout']):
            if not p2sh_tx and tx_out['scriptpubkey_type'] == 'p2sh':
                p2sh_tx = (tx_idx, tx, i)
                break
            if not p2pkh_tx and tx_out['scriptpubkey_type'] == 'p2pkh':
                p2pkh_tx = (tx_idx, tx, i)
                break

    p2sh_tx_hex = self.mempool_space.tx_hex(p2sh_tx[1]['txid'])
    p2pkh_tx_hex = self.mempool_space.tx_hex(p2pkh_tx[1]['txid'])

    p2sh_txo = Transaction.from_raw(p2sh_tx_hex)
    p2pkh_txo = Transaction.from_raw(p2pkh_tx_hex)

    vfy_p2sh_tx_hex = self.btc.getrawtransaction(p2sh_tx[1]['txid'], blockhash)
    assert p2sh_tx_hex == vfy_p2sh_tx_hex

    vfy_p2pkh_tx_hex = self.btc.getrawtransaction(p2pkh_tx[1]['txid'], blockhash)
    assert p2pkh_tx_hex == vfy_p2pkh_tx_hex

    if p2sh_txo.get_txid() != p2sh_tx[1]['txid']:
        print('Calculated P2SH TX ID mismatch! Raw tx:')
        print(vfy_p2sh_tx_hex)
        print()
        sys.exit(9)

    if p2pkh_txo.get_txid() != p2pkh_tx[1]['txid']:
        print('Calculated P2PKH TX ID mismatch! Raw tx:')
        print(vfy_p2pkh_tx_hex)
        print()
        sys.exit(9)

    # Verify P2SH transaction on-chain
    p2sh_tx_proof = self.mempool_space.tx_merkleproof(p2sh_tx[1]['txid'])
    result = BtcTxVerifier.functions.verifiedP2SHPayment(
        0,                                           # minConfirmations
        p2sh_tx_proof['block_height'],               # blockNum
        [                                            # inclusionProof
            '0x'+blockheader,                        #   blockHeader
            '0x'+p2sh_tx[1]['txid'],                 #   txId
            p2sh_tx_proof['pos'],                    #   txIndex
            '0x' + ''.join(p2sh_tx_proof['merkle']), #   txMerkleProof
            '0x' + p2sh_txo.to_bytes(False).hex(),   #   rawTx
        ],
        p2sh_tx[2]                                   # txOutIdx
        ).call()
    assert P2shAddress(hash160=result[0].hex()).to_string() == p2sh_tx[1]['vout'][p2sh_tx[2]]['scriptpubkey_address']
    assert result[1] == p2sh_tx[1]['vout'][p2sh_tx[2]]['value']

    # Verify P2PKH transaction on-chain
    p2pkh_tx_proof = self.mempool_space.tx_merkleproof(p2pkh_tx[1]['txid'])
    result = BtcTxVerifier.functions.verifiedP2PKHPayment(
        0,                                            # minConfirmations
        p2pkh_tx_proof['block_height'],               # blockNum
        [                                             # inclusionProof
            '0x'+blockheader,                         #   blockHeader
            '0x'+p2pkh_tx[1]['txid'],                 #   txId
            p2pkh_tx_proof['pos'],                    #   txIndex
            '0x' + ''.join(p2pkh_tx_proof['merkle']), #   txMerkleProof
            '0x' + p2pkh_txo.to_bytes(False).hex(),   #   rawTx
        ],
        p2pkh_tx[2]                                   # txOutIdx
        ).call()
    assert P2pkhAddress(hash160=result[0].hex()).to_string() == p2pkh_tx[1]['vout'][p2pkh_tx[2]]['scriptpubkey_address']
    assert result[1] == p2pkh_tx[1]['vout'][p2pkh_tx[2]]['value']

    LOGGER.info('BtTxVerifier OK')


class CmdTest(Cmd):
    deploy_file: Optional[str]
    gasprice: Optional[int]
    components: list[ContractChoice] | set[ContractChoice]

    @classmethod
    def setup(cls, parser: ArgumentParser):
        super().setup(parser)
        parser.add_argument('-f', '--deploy-file', metavar='path.json', type=str,
                            help='Read contract deployment info from file (JSON)')
        parser.add_argument('-g', '--gasprice', metavar='wei', type=int,
                            default=DEFAULT_GAS_PRICE,
                            help='Specify custom gasPrice in wei for deploy tx (default: 100 gwei)')
        parser.add_argument('components', nargs='*', type=ContractChoice,
                            help='Which on-chain components to test (default: all testable)')

    def __call__(self):
        contract_info:dict[str,ContractInfo] = {}
        if self.deploy_file:
            if os.path.exists(self.deploy_file):
                with open(self.deploy_file, 'r') as handle:
                    contract_info = json.load(handle)
                    LOGGER.debug('Loaded previous deployment info for %s from %s',
                                ','.join(contract_info.keys()),
                                self.deploy_file)
            else:
                LOGGER.error('Cannot find %s', self.deploy_file)
                return __LINE__

        if not self.components:
            self.components = list(ContractChoice)

        if ContractChoice.BtcTxVerifier in self.components:
            test_BtTxVerifier(self, contract_info)
