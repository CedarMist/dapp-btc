# SPDX-License-Identifier: Apache-2.0

import hashlib

def sha256(s:bytes) -> bytes:
    return hashlib.sha256(s).digest()


def double_sha256(s:bytes) -> bytes:
    return sha256(sha256(s))


def merkle_build(hashes:list[bytes]) -> bytes|None:
    while len(hashes) > 1:
        size = len(hashes)
        hashes = [double_sha256(hashes[i] + hashes[min(i + 1, size - 1)])
                  for i in range(0, size, 2)]
    if hashes:
        return hashes[0]
    return None


def hex2revbytes(x:bytes|str) -> bytes:
    """Convert a hexadecimal encoded byte string, to bytes, then reversed"""
    if isinstance(x,bytes):
        return x
    # NOTE: hashes returned by JSON-RPC API are in reverse byte order
    return bytes.fromhex(x)[::-1]


def bytes2revhex(x:str|bytes) -> str:
    if isinstance(x, bytes):
        return x[::-1].hex()
    return x
