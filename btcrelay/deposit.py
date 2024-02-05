# SPDX-License-Identifier: Apache-2.0

from os import urandom
from argparse import ArgumentParser

from .cmd import Cmd
from .constants import LOGGER


class CmdDeposit(Cmd):
    seed: str | None
    owner: str | None

    @classmethod
    def setup(cls, parser:ArgumentParser) -> None:
        super().setup(parser)
        parser.add_argument('--seed', help='Seed used to derive deposit', required=False)
        parser.add_argument('--owner', help='New owner of the deposit', required=False)

    def __call__(self) -> int:
        d = self.dcim.contract_instance('BTCDeposit', self.web3)
        createDerivedWithoutEpoch = d.functions.createDerivedWithoutEpoch

        # Generate a random seed if not provided
        if self.seed is None:
            self.seed = urandom(32).hex()

        seed_bytes = bytes.fromhex(self.seed)
        if len(seed_bytes) != 32:
            raise RuntimeError("seed wrong length! Must be 32 bytes")

        if self.owner is None:
            self.owner = self.key.address

        print('Seed', self.seed)
        print('Owner', self.owner)

        result = createDerivedWithoutEpoch(self.owner, seed_bytes).call()
        out_pubkeyAddress, out_keypairId, out_epoch = result
        print(result)

        # TODO: display deposit address

        # TODO: wait for transaction to be confirmed

        # TODO: submit `depositDerived` transaction
