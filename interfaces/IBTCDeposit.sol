// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BtcTxProof} from "./BtcTxProof.sol";
import {IERC165} from "./IERC165.sol";
import {IUsesBtcRelay} from "./IUsesBtcRelay.sol";

interface IBTCDeposit is IERC165, IUsesBtcRelay {
    function getSecret(bytes32 in_keypairId)
        external view
        returns (bytes20 out_btcAddress, bytes32 out_secret);

    function getMeta(bytes32 in_keypairId)
        external view
        returns (uint64 out_burnHeight, uint64 out_sats);

    function create( address in_owner )
        external
        returns (bytes20 out_btcAddress, bytes32 out_keypairId, uint256 out_minConfirmations);

    function deposit(
        uint32 blockNum,
        BtcTxProof calldata inclusionProof,
        uint32 txOutIx,
        bytes32 keypairId
    )
        external
        returns (uint64 out_sats);

    function burn(bytes32 in_keypairId)
        external;

    function safeTransferMany(address in_to, bytes32[] calldata in_keypairId)
        external;
}
