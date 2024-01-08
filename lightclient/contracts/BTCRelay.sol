// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "../../interfaces/IERC165.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {AbstractBTCRelay} from "./lib/AbstractBTCRelay.sol";

contract BTCRelay is AbstractBTCRelay {
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

    function getChainParams() external view returns (ChainParams memory)
    {
        if( isTestnet ) {
            return ChainParams({
                name: "btc-testnet",
                magic: 0x0b110907,
                pubkeyAddrPrefix: 113,
                scriptAddrPrefix: 196
            });
        }

        return ChainParams({
            name: "btc-mainnet",
            magic: 0xf9beb4d9,
            pubkeyAddrPrefix: 30,
            scriptAddrPrefix: 22
        });
    }
}
