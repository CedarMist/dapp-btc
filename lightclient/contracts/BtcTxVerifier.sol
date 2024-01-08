// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBtcTxVerifier,BtcTxProof} from "../../interfaces/IBtcTxVerifier.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {BtcProofUtils} from "./lib/BtcProofUtils.sol";

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
// BtcVerifier implements a merkle proof that a Bitcoin payment succeeded. It
// uses BtcMirror as a source of truth for which Bitcoin block hashes are in the
// canonical chain.
contract BtcTxVerifier is IERC165, IUsesBtcRelay, IBtcTxVerifier {
    IBtcMirror private immutable m_mirror;

    constructor(IBtcMirror in_mirror)
    {
        require( in_mirror.supportsInterface(type(IBtcMirror).interfaceId) );

        m_mirror = in_mirror;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        external pure override
        returns (bool)
    {
        return interfaceId == type(IBtcTxVerifier).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IUsesBtcRelay).interfaceId;
    }

    function _getConfirmedBlockHash(
        uint256 minConfirmations,
        uint256 in_blockNum
    )
        internal view
        returns (bytes32)
    {
        uint256 mirrorHeight = m_mirror.getLatestBlockHeight();

        require(
            mirrorHeight >= in_blockNum,
            "Bitcoin Mirror doesn't have that block yet"
        );

        require(
            mirrorHeight + 1 >= minConfirmations + in_blockNum,
            "Not enough Bitcoin block confirmations"
        );

        return m_mirror.getBlockHash(in_blockNum);
    }

    function verifiedP2PKHPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx
    )
        external view override
        returns (bytes20 out_actualPubkeyhash, uint64 out_sats)
    {
        bytes32 blockHash = _getConfirmedBlockHash(minConfirmations, blockNum);

        (out_actualPubkeyhash, out_sats) = BtcProofUtils.validateP2PKHPayment(
            blockHash,
            inclusionProof,
            txOutIx
        );
    }

    function verifiedP2SHPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx
    )
        external view override
        returns (bytes20 out_actualScripthash, uint64 out_sats)
    {
        bytes32 blockHash = _getConfirmedBlockHash(minConfirmations, blockNum);

        (out_actualScripthash, out_sats) = BtcProofUtils.validateP2SHPayment(
            blockHash,
            inclusionProof,
            txOutIx
        );
    }

    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_mirror;
    }
}