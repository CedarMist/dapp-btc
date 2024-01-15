// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC721ManyReceiver} from "./IERC721.sol";
import {IERC165} from "./IERC165.sol";
import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC20Burnable} from "./IERC20Burnable.sol";
import {IUsesBtcRelay} from "./IUsesBtcRelay.sol";

interface ILiquidToken is IERC721ManyReceiver, IERC165, IERC20, IERC20Metadata, IERC20Burnable, IUsesBtcRelay {
    function getMinDenomination() external view returns (uint256);

    function getMaxDenomination() external view returns (uint256);
}
