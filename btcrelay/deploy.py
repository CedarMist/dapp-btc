# SPDX-License-Identifier: Apache-2.0

from time import time
from typing import Optional
from argparse import ArgumentParser

from web3 import Web3
from web3.types import TxParams
from web3._utils.empty import Empty
from web3.utils.address import get_create_address

from .cmd import Cmd
from .bitcoin import bytes2revhex
from .constants import CONTRACT_NAME_T, DEFAULT_GAS_PRICE, LOGGER, __LINE__, CONTRACT_NAMES, ContractName
from .contracts import DeployedInfo, ContractInfo


class CmdDeploy(Cmd):
    yes: bool
    start_height: int
    gasprice: Optional[int]
    components: list[ContractName]

    @classmethod
    def setup(cls, parser: ArgumentParser):
        super().setup(parser)
        parser.add_argument('--start-height', type=int,
                            help='Deploy Relay, starting sync from this Bitcoin height')
        parser.add_argument('-y', '--yes', action='store_true',
                            help="Don't ask to continue, assume yes")
        parser.add_argument('-g', '--gasprice', metavar='wei', type=int,
                            default=DEFAULT_GAS_PRICE,
                            help='Specify custom gasPrice in wei for deploy tx (default: 100 gwei)')
        parser.add_argument('components', nargs='*', type=ContractName,
                            help='Which on-chain components to deploy (default: all)')

    def __call__(self):
        if self.start_height is None:
            # If no height specified, use the block prior to the last adjustment
            self.start_height = self.poly.height()
            self.start_height -= (self.start_height % 2016) + 2
        if self.start_height >= (2**32):
            LOGGER.error("height must be an unsigned uint32")
            return __LINE__
        elif self.start_height < 1:
            self.start_height = self.poly.height() + self.start_height

        account_address = self.web3.eth.default_account
        if isinstance(account_address, Empty):
            raise RuntimeError('No default account!')
        account_nonce = self.web3.eth.get_transaction_count(account_address)

        contract_info = self.dcim.load()

        deploy_todo:dict[CONTRACT_NAME_T,ContractInfo] = {}

        if self.gasprice is not None:
            if self.gasprice < 1:
                LOGGER.error('gasPrice must be positive!')
                return __LINE__

        if not self.components:
            self.components = list(ContractName)

        relay_name = self.dcim.relay_name()

        if relay_name in self.components:
            block_hash = self.poly.height2hash(self.start_height)
            block = self.poly.getheader(block_hash)
            LOGGER.info('%s height: %d (%s)', relay_name, self.start_height, bytes2revhex(block_hash))
            constructor_args = [
                '0x' + block['hash'].hex(),
                block['height'],
                block['time'],
                block['bits'],
                self.is_testnet
            ]
            BTCRelay = self.dcim.contract_factory(relay_name, self.web3)
            c = BTCRelay.constructor(*constructor_args)
            btcrelay_tx: TxParams = c.build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo[relay_name] = {
                'tx': btcrelay_tx,
                'max_fee': btcrelay_tx['gas'] * btcrelay_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None,
                'abi': BTCRelay.abi,
                'bytecode': c.bytecode,
            }
            account_nonce += 1  # type: ignore

        if ContractName.TxVerifier in self.components:
            TxVerifier = self.dcim.contract_factory('TxVerifier', self.web3)
            if relay_name in contract_info:
                BTCRelay_addr = contract_info[relay_name]['expected_address']
            else:
                BTCRelay_addr = deploy_todo[relay_name]['expected_address']
            constructor_args = [BTCRelay_addr]
            c = TxVerifier.constructor(*constructor_args)
            txverifier_tx: TxParams = c.build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['TxVerifier'] = {
                'tx': txverifier_tx,
                'max_fee': txverifier_tx['gas'] * txverifier_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None,
                'abi': TxVerifier.abi,
                'bytecode': c.bytecode
            }
            account_nonce += 1  # type: ignore

        if ContractName.BTCDeposit in self.components:
            BTCDeposit = self.dcim.contract_factory('BTCDeposit', self.web3)
            if 'TxVerifier' in contract_info:
                TxVerifier_addr = contract_info['TxVerifier']['expected_address']
            else:
                TxVerifier_addr = deploy_todo['TxVerifier']['expected_address']
            constructor_args = [TxVerifier_addr]
            c = BTCDeposit.constructor(*constructor_args)
            btcdeposit_tx: TxParams = c.build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo['BTCDeposit'] = {
                'tx': btcdeposit_tx,
                'max_fee': btcdeposit_tx['gas'] * btcdeposit_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None,
                'abi': BTCDeposit.abi,
                'bytecode': c.bytecode
            }
            account_nonce += 1  # type: ignore

        token_name = self.dcim.token_name()
        if token_name in self.components:
            LiquidToken = self.dcim.contract_factory(token_name, self.web3)
            if 'BTCDeposit' in contract_info:
                BTCDeposit_addr = contract_info['BTCDeposit']['expected_address']
            else:
                BTCDeposit_addr = deploy_todo['BTCDeposit']['expected_address']
            constructor_args = [BTCDeposit_addr]
            c = LiquidToken.constructor(*constructor_args)
            liquidbtc_tx: TxParams = c.build_transaction({
                'gasPrice': self.gasprice
            })
            deploy_todo[token_name] = {
                'tx': liquidbtc_tx,
                'max_fee': liquidbtc_tx['gas'] * liquidbtc_tx['gasPrice'],
                'expected_address': get_create_address(account_address, account_nonce),
                'constructor_args': constructor_args,
                'account_address': account_address,
                'account_nonce': account_nonce,
                'deployed': None,
                'abi': LiquidToken.abi,
                'bytecode': c.bytecode
            }
            account_nonce += 1  # type: ignore

        if not len(deploy_todo):
            LOGGER.error('No contracts to deploy! Something has gone wrong!')
            return __LINE__

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
            self.dcim.update(contract_name, v)
            contract_info[contract_name] = v

            # Log details about deploy transaction
            LOGGER.info('%s block:%d gas:%d cost:%s waited:%.02fs',
                        contract_name,
                        receipt['blockNumber'],
                        receipt['gasUsed'],
                        Web3.from_wei(receipt['gasUsed'] * di['effective_gas_price'], 'ether'),
                        round(di['time_end'] - di['time_start'],2))

        return 0
