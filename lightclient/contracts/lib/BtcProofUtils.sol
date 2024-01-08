// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Endian} from "./Endian.sol";
import {BtcTxProof} from "../../../interfaces/BtcTxProof.sol";

/**
 * @dev A parsed (but NOT fully validated) Bitcoin transaction.
 */
struct BitcoinTx {
    /**
     * @dev Whether we successfully parsed this Bitcoin TX, valid version etc.
     *      Does NOT check signatures or whether inputs are unspent.
     */
    bool validFormat;
    /**
     * @dev Version. Must be 1 or 2.
     */
    uint32 version;
    /**
     * @dev Each input spends a previous UTXO.
     */
    BitcoinTxIn[] inputs;
    /**
     * @dev Each output creates a new UTXO.
     */
    BitcoinTxOut[] outputs;
    /**
     * @dev Locktime. Either 0 for no lock, blocks if <500k, or seconds.
     */
    uint32 locktime;
}

struct BitcoinTxIn {
    /** @dev Previous transaction. */
    uint256 prevTxID;
    /** @dev Specific output from that transaction. */
    uint32 prevTxIndex;
    /** @dev Mostly useless for tx v1, BIP68 Relative Lock Time for tx v2. */
    uint32 seqNo;
    /** @dev Input script length */
    uint32 scriptLen;
    /** @dev Input script, spending a previous UTXO. Over 32 bytes unsupported. */
    bytes32 script;
}

struct BitcoinTxOut {
    /** @dev TXO value, in satoshis */
    uint64 valueSats;
    /** @dev Output script length */
    uint32 scriptLen;
    /** @dev Output script. Over 32 bytes unsupported.  */
    bytes32 script;
}

//
//                                        #
//                                       # #
//                                      # # #
//                                     # # # #
//                                    # # # # #
//                                   # # # # # #
//                                  # # # # # # #
//                                 # # # # # # # #
//                                # # # # # # # # #
//                               # # # # # # # # # #
//                              # # # # # # # # # # #
//                                   # # # # # #
//                               +        #        +
//                                ++++         ++++
//                                  ++++++ ++++++
//                                    +++++++++
//                                      +++++
//                                        +
//
// BtcProofUtils provides functions to prove things about Bitcoin transactions.
// Verifies merkle inclusion proofs, transaction IDs, and payment details.
library BtcProofUtils {
    function _getVerifiedTxOutput(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx
    )
        internal pure
        returns (BitcoinTxOut memory out_txOutput)
    {
        // 5. Block header to block hash
        require(
            getBlockHash(txProof.blockHeader) == blockHash,
            "Block hash mismatch"
        );

        // 4. and 3. Transaction ID included in block
        bytes32 blockTxRoot = getBlockTxMerkleRoot(txProof.blockHeader);
        bytes32 txRoot = getTxMerkleRoot(
            txProof.txId,
            txProof.txIndex,
            txProof.txMerkleProof
        );
        require(blockTxRoot == txRoot, "Tx merkle root mismatch");

        // 2. Raw transaction to TxID
        require(getTxID(txProof.rawTx) == txProof.txId, "Tx ID mismatch");

        // 1. Finally, validate raw transaction pays stated recipient.
        BitcoinTx memory parsedTx = parseBitcoinTx(txProof.rawTx);

        out_txOutput = parsedTx.outputs[txOutIx];
    }

    /**
     * @dev Validates that a given payment appears under a given block hash.
     *
     * This verifies all of the following:
     * 1. Raw transaction really does pay X satoshis to Y script hash.
     * 2. Raw transaction hashes to the given transaction ID.
     * 3. Transaction ID appears under transaction root (Merkle proof).
     * 4. Transaction root is part of the block header.
     * 5. Block header hashes to a given block hash.
     *
     * The caller must separately verify that the block hash is in the chain.
     *
     * The function reverts if any condition is false, if all checks succeed it
     * returns the public key hash of the output and the number of sats paid.
     */
    function validateP2PKHPayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx
    )
        internal pure
        returns (bytes20 out_destPubkeyHash, uint64 out_sats)
    {
        BitcoinTxOut memory txo = _getVerifiedTxOutput(blockHash, txProof, txOutIx);

        out_destPubkeyHash = getP2PKH(txo.scriptLen, txo.script);

        out_sats = txo.valueSats;
    }

    function validateP2SHPayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx
    )
        internal pure
        returns (bytes20 out_destScriptHash, uint64 out_sats)
    {
        BitcoinTxOut memory txo = _getVerifiedTxOutput(blockHash, txProof, txOutIx);

        out_destScriptHash = getP2SH(txo.scriptLen, txo.script);

        out_sats = txo.valueSats;
    }

    /**
     * @dev Compute a block hash given a block header.
     */
    function getBlockHash(bytes calldata blockHeader)
        public pure
        returns (bytes32)
    {
        require(blockHeader.length == 80);
        bytes32 ret = sha256(abi.encodePacked(sha256(blockHeader)));
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Get the transactions merkle root given a block header.
     */
    function getBlockTxMerkleRoot(bytes calldata blockHeader)
        public pure
        returns (bytes32)
    {
        require(blockHeader.length == 80);
        return bytes32(blockHeader[36:68]);
    }

    /**
     * @dev Recomputes the transactions root given a merkle proof.
     */
    function getTxMerkleRoot(
        bytes32 txId,
        uint256 txIndex,
        bytes calldata siblings
    )
        public pure
        returns (bytes32)
    {
        bytes32 ret = bytes32(Endian.reverse256(uint256(txId)));
        uint256 len = siblings.length / 32;
        for (uint256 i = 0; i < len; i++) {
            bytes32 s = bytes32(
                Endian.reverse256(
                    uint256(bytes32(siblings[i * 32:(i + 1) * 32]))
                )
            );
            if (txIndex & 1 == 0) {
                ret = doubleSha(abi.encodePacked(ret, s));
            } else {
                ret = doubleSha(abi.encodePacked(s, ret));
            }
            txIndex = txIndex >> 1;
        }
        return ret;
    }

    /**
     * @dev Computes the ubiquitious Bitcoin SHA256(SHA256(x))
     */
    function doubleSha(bytes memory buf)
        internal pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(sha256(buf)));
    }

    /**
     * @dev Recomputes the transaction ID for a raw transaction.
     */
    function getTxID(bytes calldata rawTransaction)
        public pure
        returns (bytes32)
    {
        bytes32 ret = doubleSha(rawTransaction);
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Parses a HASH-SERIALIZED Bitcoin transaction.
     *      This means no flags and no segwit witnesses.
     */
    function parseBitcoinTx(bytes calldata rawTx)
        public pure
        returns (BitcoinTx memory ret)
    {
        ret.version = Endian.reverse32(uint32(bytes4(rawTx[0:4])));
        if (ret.version < 1 || ret.version > 2) {
            return ret; // invalid version
        }

        // Read transaction inputs
        uint256 offset = 4;
        uint256 nInputs;
        (nInputs, offset) = readVarInt(rawTx, offset);
        ret.inputs = new BitcoinTxIn[](nInputs);
        for (uint256 i = 0; i < nInputs; i++) {
            BitcoinTxIn memory txIn;
            txIn.prevTxID = Endian.reverse256(
                uint256(bytes32(rawTx[offset:offset + 32]))
            );
            offset += 32;
            txIn.prevTxIndex = Endian.reverse32(
                uint32(bytes4(rawTx[offset:offset + 4]))
            );
            offset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);
            txIn.scriptLen = uint32(nInScriptBytes);
            txIn.script = bytes32(rawTx[offset:offset + nInScriptBytes]);
            offset += nInScriptBytes;
            txIn.seqNo = Endian.reverse32(
                uint32(bytes4(rawTx[offset:offset + 4]))
            );
            offset += 4;
            ret.inputs[i] = txIn;
        }

        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        ret.outputs = new BitcoinTxOut[](nOutputs);
        for (uint256 i = 0; i < nOutputs; i++) {
            BitcoinTxOut memory txOut;
            txOut.valueSats = Endian.reverse64(
                uint64(bytes8(rawTx[offset:offset + 8]))
            );
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);
            txOut.scriptLen = uint32(nOutScriptBytes);
            txOut.script = bytes32(rawTx[offset:offset + nOutScriptBytes]);
            offset += nOutScriptBytes;
            ret.outputs[i] = txOut;
        }

        // Finally, read locktime, the last four bytes in the tx.
        ret.locktime = Endian.reverse32(
            uint32(bytes4(rawTx[offset:offset + 4]))
        );
        offset += 4;
        if (offset != rawTx.length) {
            return ret; // Extra data at end of transaction.
        }

        // Parsing complete, sanity checks passed, return success.
        ret.validFormat = true;
        return ret;
    }

    /** Reads a Bitcoin-serialized varint = a u256 serialized in 1-9 bytes. */
    function readVarInt(bytes calldata buf, uint256 offset)
        public
        pure
        returns (uint256 val, uint256 newOffset)
    {
        uint8 pivot = uint8(buf[offset]);
        if (pivot < 0xfd) {
            val = pivot;
            newOffset = offset + 1;
        } else if (pivot == 0xfd) {
            val = Endian.reverse16(uint16(bytes2(buf[offset + 1:offset + 3])));
            newOffset = offset + 3;
        } else if (pivot == 0xfe) {
            val = Endian.reverse32(uint32(bytes4(buf[offset + 1:offset + 5])));
            newOffset = offset + 5;
        } else {
            // pivot == 0xff
            val = Endian.reverse64(uint64(bytes8(buf[offset + 1:offset + 9])));
            newOffset = offset + 9;
        }
    }

    bytes1 private constant OP_CHECKSIG = 0xac;
    bytes1 private constant OP_EQUALVERIFY = 0x88;
    bytes1 private constant OP_HASH160 = 0xa9;
    bytes1 private constant OP_DUP = 0x76;
    bytes1 private constant OP_EQUAL = 0x87;
    bytes1 private constant OP_PUSHBYTES_20 = 0x14;

    /**
     * @dev Verifies that `script` is a standard P2PKH (pay to public key hash) tx.
     * https://learnmeabitcoin.com/technical/p2pkh
     * @return hash The recipient public key hash, or 0 if verification failed
     */
    function getP2PKH(uint256 scriptLen, bytes32 script)
        internal
        pure
        returns (bytes20)
    {
        if( scriptLen != 25
         || script[0] != OP_DUP
         || script[1] != OP_HASH160
         || script[2] != OP_PUSHBYTES_20
         || script[23] != OP_EQUALVERIFY
         || script[24] != OP_CHECKSIG
        ) {
            return 0;
        }

        uint256 sHash = (uint256(script) >> 72) &
            0x00ffffffffffffffffffffffffffffffffffffffff;

        return bytes20(uint160(sHash));
    }

    /**
     * @dev Verifies that `script` is a standard P2SH (pay to script hash) tx.
     * @return hash The recipient script hash, or 0 if verification failed.
     */
    function getP2SH(uint256 scriptLen, bytes32 script)
        internal
        pure
        returns (bytes20)
    {
        if( scriptLen != 23
         || script[0] != OP_HASH160
         || script[1] != OP_PUSHBYTES_20
         || script[22] != OP_EQUAL
        ) {
            return 0;
        }

        uint256 sHash = (uint256(script) >> 80) &
            0x00ffffffffffffffffffffffffffffffffffffffff;

        return bytes20(uint160(sHash));
    }
}
