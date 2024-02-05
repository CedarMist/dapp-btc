import sys
from argparse import ArgumentParser

from .cmd import Cmd
from .deploy import CmdDeploy
from .fetchd import CmdFetchd
from .test import CmdTest
from .deposit import CmdDeposit

def main() -> None:
    argv = sys.argv
    parser = ArgumentParser(description='BTC Relay', prog=argv[0])
    subparsers = parser.add_subparsers(title='command', help='Commands')

    CmdDeploy.setup(subparsers.add_parser('deploy', help='Deploy BTCRelay contract'))
    CmdFetchd.setup(subparsers.add_parser('fetchd', help='Run BTCRelay synchronizer / fetch daemon'))
    CmdTest.setup(subparsers.add_parser('test', help='Run tests'))
    CmdDeposit.setup(subparsers.add_parser('deposit', help='Make a BTC deposit'))

    args:Cmd = parser.parse_args(argv[1:])  # type: ignore
    if ('func' not in args) or (args.func is None):
        parser.print_help()
        sys.exit(1)

    result = Cmd.run(args)
    if result is None:
        return 0
    sys.exit(int(str(result)))

if __name__ == "__main__":
    main()
