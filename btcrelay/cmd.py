# SPDX-License-Identifier: Apache-2.0

from typing import Callable, Optional
from argparse import ArgumentParser, Namespace

from web3 import Web3
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.middleware.signing import construct_sign_and_send_raw_middleware

from .contracts import sapphire_chain_name, DeployedContractInfoManager
from .constants import (
    CHAIN_CHOICES, DEFAULT_WALLET, SAPPHIRE_CHAIN_T,
    SAPPHIRE_CHOICES, LOGGER_LEVELS, DEFAULT_SAPPHIRE_RPC_URLS,
    LOGGER_LEVEL_NAMES_T, LOGGER, BTC_CHAIN_T, __LINE__
)
from .apis.poly import PolyAPI

class Cmd(Namespace):
    loglevel: LOGGER_LEVEL_NAMES_T
    func: Callable[['Cmd'],int]
    web3: Web3
    key: LocalAccount
    btc_rpc_url: Optional[str]
    chain: BTC_CHAIN_T
    sapphire: SAPPHIRE_CHAIN_T
    sapphire_rpc: str
    is_testnet: bool
    poly: PolyAPI
    dcim: DeployedContractInfoManager

    @classmethod
    def run(cls, args:'Cmd') -> int:
        """
        Post-processing of commandline arguments
        Ensures RPC endpoints & wallets are active etc.
        Then runs the
        """
        LOGGER.setLevel(LOGGER_LEVELS[args.loglevel])

        args.is_testnet = 'mainnet' not in args.chain

        args.poly = PolyAPI(args.chain, args.btc_rpc_url)

        args.dcim = DeployedContractInfoManager(args.chain, args.sapphire)

        # Configure Sapphire Web3.py
        if not args.sapphire_rpc:
            args.sapphire_rpc = DEFAULT_SAPPHIRE_RPC_URLS[args.sapphire]
        w3 = args.web3 = arg_eth(args.sapphire_rpc)

        # Setup ETH API, attach signer
        key = args.key
        w3.middleware_onion.add(construct_sign_and_send_raw_middleware(key))
        w3.eth.default_account = key.address

        # Check ETH API works
        try:
            balance = w3.eth.get_balance(key.address)
        except Exception as ex:
            LOGGER.exception(f'Unable to fetch balance from Web3 RPC: {args.sapphire_rpc}', exc_info=ex)
            return __LINE__()
        if balance == 0:
            LOGGER.error("Error! Account %s has 0 balance", key.address,)
            return __LINE__()

        chain_id = w3.eth.chain_id
        LOGGER.debug('%s chainId:%d account:%s balance:%s',
                     sapphire_chain_name(chain_id), chain_id, key.address,
                     Web3.from_wei(balance, 'ether'))

        return args.func(args)

    @classmethod
    def setup(cls, parser:ArgumentParser) -> None:
        parser.add_argument('--loglevel', metavar='level',
                            choices=LOGGER_LEVELS.keys(), default='info',
                            help="Logging level, don't display below this level (%s)" % (', '.join(LOGGER_LEVELS.keys())))
        parser.add_argument('-k', '--key', metavar='0x...',
                            help='32 byte hex secret key for Web3 (env: BTCRELAY_WALLET)',
                            type=Account.from_key, default=DEFAULT_WALLET)
        parser.add_argument('--btc-rpc-url', metavar='url', type=str,
                            help='Bitcoin JSON-RPC endpoint (env: BTCRELAY_BTCRPC)')
        parser.add_argument('--chain', choices=CHAIN_CHOICES, required=True)
        parser.add_argument('--sapphire', choices=SAPPHIRE_CHOICES, required=True)
        parser.add_argument('--sapphire-rpc', metavar='url',
                            help='Sapphire Ethereum compatible JSON-RPC endpoint (env: BTCRELAY_ETHRPC)')
        parser.set_defaults(func=cls.__call__)


def arg_eth(url:str) -> Web3:
    if url.startswith(('http', 'https')):
        return Web3(Web3.HTTPProvider(url))
    elif url.startswith(('ws', 'wss')):
        return Web3(Web3.WebsocketProvider(url))
    raise RuntimeError(f'Error! "{url}" not valid JSON-RPC url')
