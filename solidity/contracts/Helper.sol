// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {IERC165} from "../../interfaces/IERC165.sol";

contract Helper is IUsesBtcRelay {

    IBTCDeposit private immutable m_deposit;

    constructor (IBTCDeposit in_deposit)
    {
        m_deposit = in_deposit;
    }

    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_deposit.getBtcRelay();
    }

    function create (uint in_n, bytes32 in_blind)
        external
    {
        create(msg.sender, in_n, in_blind);
    }

    event OnCreated ( bytes32 tag, bytes20 blind_pubkey, bytes32 blind_id );

    function create (address in_owner, uint in_n, bytes32 in_blind)
        public
    {
        bytes32 tag = keccak256(abi.encodePacked(in_blind));

        for( uint256 i = 0; i < in_n; i++ )
        {
            bytes32 y = keccak256(abi.encodePacked(in_blind, i));

            bytes20 z = bytes20(keccak256(abi.encodePacked(y)));

            (bytes20 addr, bytes32 kpid, uint256 minconfs) = m_deposit.create(in_owner);

            emit OnCreated(tag, addr ^ bytes20(y), kpid ^ z);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        external pure
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IUsesBtcRelay).interfaceId;
    }
}
