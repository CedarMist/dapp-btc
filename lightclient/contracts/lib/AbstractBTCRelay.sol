// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "../../../interfaces/IERC165.sol";
import {IBtcMirror} from "../../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../../interfaces/IUsesBtcRelay.sol";
import {AbstractRelay} from "./AbstractRelay.sol";

abstract contract AbstractBTCRelay is AbstractRelay {
    uint private constant RETARGET_PERIOD = 2016;

    mapping(uint256 => uint256) internal m_periodTargets;

    constructor(
        bytes32 in_blockHash,
        uint256 in_blockHeight,
        uint32 in_time,
        uint256 in_bits,
        bool in_isTestnet
    )
        AbstractRelay(
            in_blockHash,
            in_blockHeight,
            in_time,
            in_isTestnet)
    {
        m_periodTargets[in_blockHeight / RETARGET_PERIOD] = nBitsToTarget(in_bits);
    }

    function _checkRetarget(uint256 currentHeight, uint256 target) override
        internal virtual
    {
        // Difficulty retargeting, for BTC this is every 2016 blocks (14 days)
        uint256 period = currentHeight / RETARGET_PERIOD;

        if( (currentHeight % RETARGET_PERIOD) == 0 )
        {
            uint256 lastTarget = m_periodTargets[period - 1];

            // NOTE: we don't calulate the new target, just enforce
            // the constraint to a factor of 4 in either direction
            if( target < (lastTarget >> 2) || target > (lastTarget << 2) )
            {
                require(isTestnet, "INVALID_RETARGET");
            }

            m_periodTargets[period] = target;
        }
        else if( target != m_periodTargets[period] )
        {
            require(isTestnet, "WRONG_TARGET");
        }
    }
}
