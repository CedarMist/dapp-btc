// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBtcMirror} from "./IBtcMirror.sol";
import {IERC165} from "./IERC165.sol";

interface IUsesBtcRelay is IERC165 {
    /** @notice Returns the underlying mirror associated with this verifier. */
    function getBtcRelay() external view returns (IBtcMirror);
}