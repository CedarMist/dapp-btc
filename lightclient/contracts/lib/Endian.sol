// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// Bitwise math helpers for dealing with Bitcoin block headers.
// Bitcoin block fields are little-endian. Must flip to big-endian for EVM.
library Endian {
    function reverse256(uint256 input) internal pure returns (uint256 v) {
        v = input;

        // swap bytes
        uint256 pat1 = 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00;
        v = ((v & pat1) >> 8) | ((v & ~pat1) << 8);

        // swap 2-byte long pairs
        uint256 pat2 = 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000;
        v = ((v & pat2) >> 16) | ((v & ~pat2) << 16);

        // swap 4-byte long pairs
        uint256 pat4 = 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000;
        v = ((v & pat4) >> 32) | ((v & ~pat4) << 32);

        // swap 8-byte long pairs
        uint256 pat8 = 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000;
        v = ((v & pat8) >> 64) | ((v & ~pat8) << 64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    function reverse64(uint64 input) internal pure returns (uint64 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    function reverse32(uint32 input) internal pure returns (uint32 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    function reverse16(uint16 input) internal pure returns (uint16 v) {
        v = input;

        // swap bytes
        v = (v >> 8) | (v << 8);
    }
}
