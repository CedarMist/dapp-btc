// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {AbstractLiquidToken} from './lib/AbstractLiquidToken.sol';

contract LiquidLTC is AbstractLiquidToken, IERC20Metadata
{
    // Denominations are powers of 2, we allow 15 unique denominations
    // Values below the minimum denomination are 'change' or 'dust' and are ignored
    uint256 constant private MIN_SHL = 23;
    uint256 constant private MAX_SHL = 37;
    uint256 constant private MIN_DENOMINATION = 1<<MIN_SHL;                                 //    0.08388608 LTC,               0b100000000000000000000000,     0x800000
    uint256 constant private MAX_DENOMINATION = 1<<MAX_SHL;                                 // 1374.38953472 LTC, 0b10000000000000000000000000000000000000, 0x2000000000
    uint256 constant private CHANGE_MASK = MIN_DENOMINATION-1;                              //    0.08388607 LTC,                0b11111111111111111111111,     0x7fffff
    uint256 constant private DENOMINATION_MASK = ((MAX_DENOMINATION<<1)-1) ^ CHANGE_MASK;   // 2748.69518336 LTC, 0b11111111111111100000000000000000000000, 0x3fff800000
    uint256 constant private DENOM_MASK_BIT_COUNT = (MAX_SHL+1)-MIN_SHL;                    // 15 == bin(DENOMINATION_MASK).count('1')

    function _getDenominationMask() override internal pure returns (uint256)
    {
        return DENOMINATION_MASK;
    }

    function _getChangeMask() override internal pure returns (uint256)
    {
        return CHANGE_MASK;
    }

    function _getDenominationBitCount() override internal pure returns (uint256)
    {
        return DENOM_MASK_BIT_COUNT;
    }

    function getMinDenomination() override public pure returns (uint256)
    {
        return MIN_DENOMINATION;
    }

    function getMaxDenomination() override public pure returns (uint256)
    {
        return MAX_DENOMINATION;
    }

    constructor(IBTCDeposit in_manager)
        AbstractLiquidToken(in_manager)
    { }

    // IERC20Metadata
    function name()
        external pure
        returns (string memory)
    {
        return "Liquid Litecoin";
    }

    // IERC20Metadata
    function symbol()
        external pure
        returns (string memory)
    {
        return "liquidLTC";
    }

    // IERC20Metadata
    function decimals()
        external pure
        returns (uint8)
    {
        return 8;
    }
}
