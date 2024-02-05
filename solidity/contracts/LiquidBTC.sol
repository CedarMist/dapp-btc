// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {AbstractLiquidToken} from './lib/AbstractLiquidToken.sol';
import {ILiquidToken} from "../../interfaces/ILiquidToken.sol";

contract LiquidBTC is AbstractLiquidToken
{
    // Denominations are powers of 2, we allow 15 unique denominations
    // Values below the minimum denomination are 'change' or 'dust' and are ignored
    uint256 constant private MIN_SHL = 20;
    uint256 constant private MAX_SHL = 34;
    uint256 constant private MIN_DENOMINATION = 1<<MIN_SHL;                                 // 0.00008192 BTC,               0b10000000000000,    0x2000
    uint256 constant private MAX_DENOMINATION = 1<<MAX_SHL;                                 // 1.34217728 BTC, 0b1000000000000000000000000000, 0x8000000
    uint256 constant private CHANGE_MASK = MIN_DENOMINATION-1;                              // 0.00008191 BTC,                0b1111111111111,    0x1fff
    uint256 constant private DENOMINATION_MASK = ((MAX_DENOMINATION<<1)-1) ^ CHANGE_MASK;   // 2.68427264 BTC, 0b1111111111111110000000000000, 0xfffe000
    uint256 constant private DENOM_MASK_BIT_COUNT = (MAX_SHL+1)-MIN_SHL;                    // 15 == bin(DENOMINATION_MASK).count('1')

    // AbstractLiquidToken
    function internal_getDenominationMask() override internal pure returns (uint256)
    {
        return DENOMINATION_MASK;
    }

    // AbstractLiquidToken
    function internal_getChangeMask() override internal pure returns (uint256)
    {
        return CHANGE_MASK;
    }

    // AbstractLiquidToken
    function internal_getDenominationBitCount() override internal pure returns (uint256)
    {
        return DENOM_MASK_BIT_COUNT;
    }

    // AbstractLiquidToken
    function getMinDenomination() override public pure returns (uint256)
    {
        return MIN_DENOMINATION;
    }

    // AbstractLiquidToken
    function getMaxDenomination() override public pure returns (uint256)
    {
        return MAX_DENOMINATION;
    }

    constructor(IBTCDeposit in_manager, address in_2771Forwarder)
        AbstractLiquidToken(in_manager, in_2771Forwarder)
    { }

    // IERC20Metadata
    function name()
        external pure
        returns (string memory)
    {
        return "Liquid Bitcoin";
    }

    // IERC20Metadata
    function symbol()
        external pure
        returns (string memory)
    {
        return "liquidBTC";
    }

    // IERC20Metadata
    function decimals()
        external pure
        returns (uint8)
    {
        return 8;
    }
}
