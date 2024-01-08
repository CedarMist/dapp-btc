import sys
from argparse import ArgumentParser

from .cmd import Cmd
from .deploy import CmdDeploy
from .fetchd import CmdFetchd
from .test import CmdTest

def main():
    argv = sys.argv
    parser = ArgumentParser(description='BTC Relay', prog=argv[0])
    subparsers = parser.add_subparsers(title='command', help='Commands')

    CmdDeploy.setup(subparsers.add_parser('deploy', help='Deploy BTCRelay contract'))
    CmdFetchd.setup(subparsers.add_parser('fetchd', help='Run BTCRelay synchronizer / fetch daemon'))
    CmdTest.setup(subparsers.add_parser('test', help='Run tests'))

    args:Cmd = parser.parse_args(argv[1:])  # type: ignore
    if ('func' not in args) or (args.func is None):
        parser.print_help()
        sys.exit(1)

    sys.exit(Cmd.run(args))

if __name__ == "__main__":
    main()
