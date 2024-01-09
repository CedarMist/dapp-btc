// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC165} from "../../interfaces/IERC165.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {AbstractBTCRelay} from "./lib/AbstractBTCRelay.sol";

contract LTCRelay is AbstractBTCRelay {
    constructor(
        bytes32 in_blockHash,
        uint256 in_blockHeight,
        uint32 in_time,
        uint256 in_bits,
        bool in_isTestnet
    )
        AbstractBTCRelay(
            in_blockHash,
            in_blockHeight,
            in_time,
            in_bits,
            in_isTestnet)
    { }

    function getChainParams()
        external view
        returns (ChainParams memory)
    {
        if( isTestnet ) {
            return ChainParams({
                name: "ltc-testnet",
                magic: 0xfdd2c8f1,
                pubkeyAddrPrefix: 111,
                scriptAddrPrefix: 196
            });
        }

        return ChainParams({
            name: "ltc-mainnet",
            magic: 0xf9c0b6db,
            pubkeyAddrPrefix: 48,
            scriptAddrPrefix: 5
        });
    }
}
