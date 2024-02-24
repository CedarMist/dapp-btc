# SPDX-License-Identifier: Apache-2.0

from os import urandom
from time import sleep
from argparse import ArgumentParser

from bitcoinutils.keys import P2pkhAddress

from .cmd import Cmd
from .constants import LOGGER, __LINE__


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

        # out_pubkeyAddress, out_keypairId, out_epoch, out_minConfirmations
        result: tuple[bytes,bytes,int,int] = createDerivedWithoutEpoch(self.owner, seed_bytes).call()
        out_pubkeyAddress = P2pkhAddress.from_hash160(result[0].hex())
        minConfirmations = result[3]

        print()
        print()
        print('       WARNING: DO NOT LOSE THESE PARAMETERS OR YOUR DEPOSIT WILL BE LOST!')
        print('v----------------------------------------------------------------------------------v')
        print(f' --owner {self.owner} --seed {self.seed}')
        print('           Owner:', self.owner, '   (Sapphire address)')
        print('            Seed:', seed_bytes.hex())
        print(' Deposit Address:', out_pubkeyAddress.to_string())
        print('      Keypair ID:', result[1].hex())
        print('           Epoch:', result[2])
        print('   Confirmations:', minConfirmations, ' needed')
        print('^----------------------------------------------------------------------------------^')
        print('       WARNING: DO NOT LOSE THESE PARAMETERS OR YOUR DEPOSIT WILL BE LOST!')
        print()
        print()

        try:
            txid = input('txid: ').strip()
        except (KeyboardInterrupt, EOFError):
            print()
            return 0

        try:
            output_idx = int(input('output idx: ').strip())
        except (KeyboardInterrupt, EOFError):
            print()
            return 0

        # Keep trying to get the tx until it's found
        printed_summary = False
        while True:
            txo = self.poly.gettxout(txid, output_idx)
            if txo is not None:
                txoaddr = txo.get('scriptPubKey', None)
                if not printed_summary:
                    printed_summary = True
                    print('Found TX :)')
                    print('   Block:', txo['bestblock'])
                    print('  Confs.:', txo['confirmations'])
                    print('   Value:', txo['value'])
                    if 'scriptPubKey' not in txo:
                        print('   No scriptPubKey found!', txo)
                        return __LINE__()
                    print('    Type:', txoaddr['type'])
                    print('    Addr:', txoaddr['address'])
                if txoaddr['address'] != out_pubkeyAddress.to_string():
                    print('Error! Address mismatch, expected', out_pubkeyAddress.to_string())
                    return __LINE__()
                if txo['confirmations'] >= minConfirmations:
                    break
                print(f"Need {minConfirmations - txo['confirmations']} more confirmations, sleeping some seconds")
            else:
                print('No tx found, sleeping some seconds')
            try:
                sleep(5)
            except KeyboardInterrupt:
                print()
                return
        print()
        proof = self.poly.gettxoutproof([txid])
        print('Proof', proof)

        # TODO: wait for transaction to be confirmed

        # TODO: submit `depositDerived` transaction
