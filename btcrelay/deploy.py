import os
import json
from time import time
from typing import Optional
from hexbytes import HexBytes
from argparse import ArgumentParser

from web3 import Web3
from web3.types import TxParams
from web3._utils.empty import Empty
from web3.datastructures import AttributeDict
from web3.utils.address import get_create_address

from .bitcoin import bytes2revhex
from .cmd import Cmd, LOGGER, __LINE__
from .constants import DEFAULT_GAS_PRICE
from .contracts import ContractChoice, DeployedInfo, ContractInfo, contract_factory


EMPTY_CONTRACT_INFO:dict[str,ContractInfo] = {}


class Encoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, HexBytes):
            return o.hex()
        if isinstance(o, bytes):
            return '0x' + o.hex()
        if isinstance(o, AttributeDict):
            return o.__dict__
        return super().default(o)


class CmdDeploy(Cmd):
    deploy_file: Optional[str]
    yes: bool
    start_height: int
    gasprice: Optional[int]
    components: list[ContractChoice] | set[ContractChoice]

    @classmethod
    def setup(cls, parser: ArgumentParser):
        super().setup(parser)
        parser.add_argument('-f', '--deploy-file', metavar='path', type=str,
                            help='Write contract addresses to file (JSON)')
        parser.add_argument('--start-height', type=int,
                            help='Deploy Relay, starting sync from this Bitcoin height')
        parser.add_argument('-y', '--yes', action='store_true',
                            help="Don't ask to continue, assume yes")
        parser.add_argument('-g', '--gasprice', metavar='wei', type=int,
                            default=DEFAULT_GAS_PRICE,
                            help='Specify custom gasPrice in wei for deploy tx (default: 100 gwei)')
        parser.add_argument('components', nargs='*', type=ContractChoice,
                            help='Which on-chain components to deploy (default: all)')

    def __call__(self):
        if self.start_height is None:
            # If no height specified, use the block prior to the last adjustment
            self.start_height = self.btc.getblockcount()
            self.start_height -= (self.start_height % 2016) + 2
        if self.start_height >= (2**32):
            LOGGER.error("height must be an unsigned uint32")
            return __LINE__
        elif self.start_height < 1:
            self.start_height = self.btc.getblockcount() + self.start_height

        self.components = set(self.components)

        account_address = self.web3.eth.default_account
        if isinstance(account_address, Empty):
            raise RuntimeError('No default account!')
        account_nonce = self.web3.eth.get_transaction_count(account_address)

        contract_info:dict[str,ContractInfo] = {}
        if self.deploy_file and os.path.exists(self.deploy_file):
            with open(self.deploy_file, 'r') as handle:
                contract_info = json.load(handle)
                LOGGER.debug('Loaded previous deployment info for %s from %s',
                             ','.join(contract_info.keys()),
                             self.deploy_file)

        deploy_todo:dict[str,ContractInfo] = {}

        if self.gasprice is not None:
            if self.gasprice < 1:
                LOGGER.error('gasPrice must be positive!')
                return __LINE__

        if not self.components:
            self.components = set(list(ContractChoice))

        if ContractChoice.BTCRelay in self.components:
            block_hash = self.btc.getblockhash(self.start_height)
            block = self.btc.getblockheader(block_hash)
            LOGGER.info('BTCRelay height: %d (%s)', self.start_height, bytes2revhex(block_hash))
            constructor_args = [
                '0x' + block['hash'].hex(),
                block['height'],
                block['time'],
                block['bits'],
                self.is_testnet
            ]
            BTCRelay = contract_factory('BTCRelay', self.web3)
            btcrelay_tx: TxParams = BTCRelay.constructor(*constructor_args).build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['BTCRelay'] = {
                'tx': btcrelay_tx,
                'max_fee': btcrelay_tx['gas'] * btcrelay_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None
            }
            account_nonce += 1  # type: ignore

        if ContractChoice.BtcTxVerifier in self.components:
            BtcTxVerifier = contract_factory('BtcTxVerifier', self.web3)
            constructor_args = [
                deploy_todo.get('BTCRelay', contract_info.get('BTCRelay', EMPTY_CONTRACT_INFO))['expected_address']
            ]
            btctxverifier_tx: TxParams = BtcTxVerifier.constructor(*constructor_args).build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['BtcTxVerifier'] = {
                'tx': btctxverifier_tx,
                'max_fee': btctxverifier_tx['gas'] * btctxverifier_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None
            }
            account_nonce += 1  # type: ignore

        if ContractChoice.BTCDeposit in self.components:
            BTCDeposit = contract_factory('BTCDeposit', self.web3)
            constructor_args = [
                deploy_todo.get('BtcTxVerifier', contract_info.get('BtcTxVerifier', EMPTY_CONTRACT_INFO))['expected_address']
            ]
            btcdeposit_tx: TxParams = BTCDeposit.constructor(*constructor_args).build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['BTCDeposit'] = {
                'tx': btcdeposit_tx,
                'max_fee': btcdeposit_tx['gas'] * btcdeposit_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None
            }
            account_nonce += 1  # type: ignore

        if ContractChoice.LiquidBTC in self.components:
            LiquidBTC = contract_factory('LiquidBTC', self.web3)
            constructor_args = [
                deploy_todo.get('BTCDeposit', contract_info.get('BTCDeposit', EMPTY_CONTRACT_INFO))['expected_address']
            ]
            liquidbtc_tx: TxParams = LiquidBTC.constructor(*constructor_args).build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['LiquidBTC'] = {
                'tx': liquidbtc_tx,
                'max_fee': liquidbtc_tx['gas'] * liquidbtc_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None
            }
            account_nonce += 1  # type: ignore

        max_fees_formatted = Web3.from_wei(sum([_['max_fee'] for _ in deploy_todo.values()]), 'ether')
        if not self.yes:
            try:
                ok = input('Max deploy fees total %s, continue? [Y/n] ' % (max_fees_formatted,))
                if ok != 'y':
                    return __LINE__
            except (KeyboardInterrupt, EOFError):
                return __LINE__
        else:
            LOGGER.debug('Cumulative maximum deploy fee: %s', max_fees_formatted)

        for contract_name, v in deploy_todo.items():
            time_start = time()
            tx_id = self.web3.eth.send_transaction(v['tx'])
            LOGGER.info('%s tx:%s size:%.2fkb',
                        contract_name, tx_id.hex(),
                        (len(v['tx']['data']) - 2) / 2 / 1024.0)
            receipt = self.web3.eth.wait_for_transaction_receipt(tx_id)
            time_end = time()

            if receipt['contractAddress'] != v['expected_address']:
                LOGGER.error('%s contract address mismatch, expected:%s actual:%s',
                             v['expected_address'], receipt['contractAddress'])
                return __LINE__

            di: DeployedInfo = {
                'tx_id': tx_id.hex(),
                'time_start': time_start,    # Keep track of how long the deploy transaction takes to be mined
                'time_end': time_end,
                'receipt': receipt,
                'effective_gas_price': receipt.get('effectiveGasPrice', DEFAULT_GAS_PRICE)
            }
            v['deployed'] = di
            contract_info[contract_name] = v

            # Log details about deploy transaction
            LOGGER.info('%s block:%d gas:%d cost:%s waited:%.02fs',
                        contract_name,
                        receipt['blockNumber'],
                        receipt['gasUsed'],
                        Web3.from_wei(receipt['gasUsed'] * di['effective_gas_price'], 'ether'),
                        round(di['time_end'] - di['time_start'],2))

            if self.deploy_file:
                with open(self.deploy_file, 'w') as handle:
                    json.dump(contract_info, handle, cls=Encoder, indent=4)

        return 0
