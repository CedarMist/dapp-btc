// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC165} from "../../interfaces/IERC165.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {AbstractRelay} from "./lib/AbstractRelay.sol";

contract DogeRelay is AbstractRelay {
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
    { }

    function _checkRetarget(uint256 currentHeight, uint256 target) override
        internal virtual
    {
        uint256 lastTarget = m_periodTargets[currentHeight - 1];

        // NOTE: we don't calulate the new target, just enforce
        // the constraint to a factor of 4 in either direction
        if( target < (lastTarget >> 2) || target > (lastTarget << 2) )
        {
            require(isTestnet, "INVALID_RETARGET");
        }

        m_periodTargets[currentHeight] = target;
    }

    function getChainParams()
        external view
        returns (ChainParams memory)
    {
        if( isTestnet ) {
            return ChainParams({
                name: "dogecoin-testnet",
                magic: 0xfcc1b7dc,
                pubkeyAddrPrefix: 113,
                scriptAddrPrefix: 196
            });
        }

        return ChainParams({
            name: "dogecoin-mainnet",
            magic: 0xc0c0c0c0,
            pubkeyAddrPrefix: 30,
            scriptAddrPrefix: 22
        });
    }
}
