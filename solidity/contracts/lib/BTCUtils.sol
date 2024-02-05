// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;


library BTCUtils {
    /// Converts a compressed 33 byte public key
    function btcAddress(bytes memory compressedPubKey)
        internal pure
        returns (bytes20)
    {
        require( compressedPubKey.length == 33 && (compressedPubKey[0] == 0x02 || compressedPubKey[0] == 0x03), "NOT PUBKEY!" );
        return bytes20(uint160(ripemd160(abi.encodePacked(sha256(compressedPubKey)))));
    }
}