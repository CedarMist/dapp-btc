// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {AbstractLiquidToken} from './lib/AbstractLiquidToken.sol';

contract LiquidDOGE is AbstractLiquidToken, IERC20Metadata
{
    // Denominations are powers of 2, we allow 15 unique denominations
    // Values below the minimum denomination are 'change' or 'dust' and are ignored
    uint256 constant private MIN_SHL = 32;
    uint256 constant private MAX_SHL = 46;
    uint256 constant private MIN_DENOMINATION = 1<<MIN_SHL;                                 //      42.94967296 DOGE,               0b100000000000000000000000000000000,    0x100000000
    uint256 constant private MAX_DENOMINATION = 1<<MAX_SHL;                                 //  703687.44177664 DOGE, 0b10000000000000000000000000000000000000000000000, 0x400000000000
    uint256 constant private CHANGE_MASK = MIN_DENOMINATION-1;                              //      42.94967295 DOGE,                0b11111111111111111111111111111111,     0xffffffff
    uint256 constant private DENOMINATION_MASK = ((MAX_DENOMINATION<<1)-1) ^ CHANGE_MASK;   // 1407331.93388032 DOGE, 0b11111111111111100000000000000000000000000000000, 0x7fff00000000
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
        return "Liquid Dogecoin";
    }

    // IERC20Metadata
    function symbol()
        external pure
        returns (string memory)
    {
        return "liquidDOGE";
    }

    // IERC20Metadata
    function decimals()
        external pure
        returns (uint8)
    {
        return 8;
    }
}
