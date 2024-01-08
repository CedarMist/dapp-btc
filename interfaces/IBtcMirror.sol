// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC165} from "./IERC165.sol";

/** @notice Tracks Bitcoin. Provides block hashes. */
interface IBtcMirror is IERC165 {
    struct ChainParams {
        string name;
        uint32 magic;
        uint8 pubkeyAddrPrefix;
        uint8 scriptAddrPrefix;
    }
    function getChainParams() external view returns (ChainParams memory);

    /** @notice Returns the Bitcoin block hash at a specific height. */
    function getBlockHash(uint256 number) external view returns (bytes32);

    /** @notice Returns the height of the latest block (tip of the chain). */
    function getLatestBlockHeight() external view returns (uint256);

    /** @notice Returns the timestamp of the lastest block, as Unix seconds. */
    function getLatestBlockTime() external view returns (uint256);
}
