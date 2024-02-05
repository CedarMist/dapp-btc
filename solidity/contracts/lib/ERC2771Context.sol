// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC2771} from "../../../interfaces/IERC2771.sol";


abstract contract ERC2771Context is IERC2771 {
    address private immutable m_2771Forwarder;

    constructor (address in_2771Forwarder)
    {
        m_2771Forwarder = in_2771Forwarder;
    }

    // IERC2771
    function isTrustedForwarder(address in_forwarder)
        public view
        returns(bool)
    {
        return in_forwarder == m_2771Forwarder;
    }

    // for IERC2771
    function internal_msgSender()
        internal view
        returns (address out_signer)
    {
        out_signer = msg.sender;

        if( msg.data.length >= 20 && out_signer == m_2771Forwarder )
        {
            assembly {
                out_signer := shr(96,calldataload(sub(calldatasize(),20)))
            }
        }
    }
}