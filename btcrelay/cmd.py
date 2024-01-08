import sys
import logging
from typing import Callable, Optional
from argparse import ArgumentParser, Namespace

from bitcoinutils.setup import setup as bitcoinutils_setup
from web3 import Web3
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.middleware import construct_sign_and_send_raw_middleware

from .contracts import chain_name
from .bitcoin import BitcoinJsonRpc, MempoolSpaceAPI, BTC_CHAIN_T
from .constants import (
    CHAIN_CHOICES, DEFAULT_WALLET, DEFAULT_GETBLOCK_URLS, SAPPHIRE_CHAIN_T,
    SAPPHIRE_CHOICES, LOGGER_LEVELS, DEFAULT_SAPPHIRE_RPC_URLS,
    LOGGER_LEVEL_NAMES_T
)

class LineImpl(object):
    def __repr__(self):
        try:
            raise Exception
        except:
            return str(sys.exc_info()[2].tb_frame.f_back.f_lineno)  # type: ignore

__LINE__ = LineImpl()


logging.basicConfig(format='# %(asctime)s %(module)s %(levelname)s:  %(message)s', level=logging.INFO, handlers=[logging.StreamHandler(sys.stderr)])
LOGGER = logging.getLogger(__name__)


class Cmd(Namespace):
    logging: LOGGER_LEVEL_NAMES_T
    func: Callable[['Cmd'],None]
    web3: Web3
    key: LocalAccount
    btc: BitcoinJsonRpc
    btc_rpc_url: Optional[str]
    mempool_space: MempoolSpaceAPI
    chain: BTC_CHAIN_T
    sapphire: SAPPHIRE_CHAIN_T
    sapphire_rpc: str
    is_testnet: bool

    @classmethod
    def run(cls, args:'Cmd'):
        """
        Post-processing of commandline arguments
        Ensures RPC endpoints & wallets are active etc.
        Then runs the
        """
        LOGGER.setLevel(LOGGER_LEVELS[args.logging])

        args.is_testnet = 'mainnet' not in args.chain

        # Setup mempool.space API
        if args.chain in ['btc-mainnet', 'btc-testnet']:
            args.mempool_space = MempoolSpaceAPI(args.chain)
        else:
            # TODO: support signet?
            raise RuntimeError(f'Unknown chain: {args.chain}')

        # Setup bitcoin utils
        if args.chain == 'btc-mainnet':
            bitcoinutils_setup('mainnet')
        elif args.chain == 'btc-signet':
            bitcoinutils_setup('signet')
        elif args.chain == 'btc-testnet':
            bitcoinutils_setup('testnet')
        else:
            raise RuntimeError(f'Unknown chain: {args.btc_chain}')

        # Setup BTC JSON-RPC
        if args.btc_rpc_url is None:
            if args.chain in DEFAULT_GETBLOCK_URLS:
                args.btc_rpc_url = DEFAULT_GETBLOCK_URLS[args.chain]
            else:
                raise RuntimeError(f'Unknown chain: {args.chain}')
        btc = args.btc = BitcoinJsonRpc(args.btc_rpc_url)

        # Configure Sapphire Web3.py
        if not args.sapphire_rpc:
            args.sapphire_rpc = DEFAULT_SAPPHIRE_RPC_URLS[args.sapphire]
        w3 = args.web3 = arg_eth(args.sapphire_rpc)

        # Setup ETH API, attach signer
        key = args.key
        w3.middleware_onion.add(construct_sign_and_send_raw_middleware(key))
        w3.eth.default_account = key.address

        # Check ETH API works
        balance = w3.eth.get_balance(key.address)
        if balance == 0:
            LOGGER.error("Error! Account %s has 0 balance", key.address,)
            sys.exit(1)

        LOGGER.debug('%s node.uptime:%.02f url:%s',
                     args.btc_chain.upper(),
                     btc.uptime() / 60 / 60 / 24,
                     args.btc_rpc_url)

        chain_id = w3.eth.chain_id
        LOGGER.debug('%s chainId:%d account:%s balance:%s',
                     chain_name(chain_id), chain_id, key.address,
                     Web3.from_wei(balance, 'ether'))

        return args.func(args)

    @classmethod
    def setup(cls, parser:ArgumentParser):
        parser.add_argument('-l', '--logging', metavar='level',
                            choices=LOGGER_LEVELS.keys(), default='info',
                            help="Logging level, don't display below this level (%s)" % (', '.join(LOGGER_LEVELS.keys())))
        parser.add_argument('-k', '--key', metavar='0x...',
                            help='32 byte hex secret key for Web3 (env: BTCRELAY_WALLET)',
                            type=Account.from_key, default=DEFAULT_WALLET)
        parser.add_argument('--btc-rpc-url', metavar='url', type=str,
                            help='Bitcoin JSON-RPC endpoint (env: BTCRELAY_BTCRPC)')
        parser.add_argument('--chain', choices=CHAIN_CHOICES, default='btc-mainnet')
        parser.add_argument('--sapphire', choices=SAPPHIRE_CHOICES, default='sapphire-mainnet')
        parser.add_argument('--sapphire-rpc', metavar='url',
                            help='Sapphire Ethereum compatible JSON-RPC endpoint (env: BTCRELAY_ETHRPC)')
        parser.set_defaults(func=cls.__call__)


def arg_eth(url:str):
    if url.startswith(('http', 'https')):
        return Web3(Web3.HTTPProvider(url))
    elif url.startswith(('ws', 'wss')):
        return Web3(Web3.WebsocketProvider(url))
    raise RuntimeError(f'Error! "{url}" not valid JSON-RPC url')
