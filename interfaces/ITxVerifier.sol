// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BtcTxProof} from "./BtcTxProof.sol";
import {IUsesBtcRelay} from "./IUsesBtcRelay.sol";
import {IERC165} from "./IERC165.sol";

/** @notice Verifies Bitcoin transaction proofs. */
interface ITxVerifier is IERC165, IUsesBtcRelay {
    /**
     * @notice Verifies that the a transaction cleared, paying a given amount to
     *         a given address. Specifically, verifies a proof that the tx was
     *         in block N, and that block N has at least M confirmations.
     */
    function verifiedP2PKHPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx
    )
        external view
        returns (bytes20 out_actualPubkeyhash, uint64 out_sats);

    function verifiedP2SHPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx
    )
        external view
        returns (bytes20 out_actualScripthash, uint64 out_sats);
}
