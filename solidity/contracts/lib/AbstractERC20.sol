// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IERC20Metadata} from "../../../interfaces/IERC20Metadata.sol";
import {IERC165} from "../../../interfaces/IERC165.sol";
import {Allowances} from "./Allowances.sol";
import {ERC2771Context} from "./ERC2771Context.sol";


abstract contract AbstractERC20 is IERC165, IERC20, ERC2771Context
{
    using Allowances for Allowances.Data;

    address constant internal BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 internal m_totalSupply;

    mapping(address => uint256) internal m_balances;

    Allowances.Data internal m_allowances;

    constructor( address in_2771Forwarder )
        ERC2771Context(in_2771Forwarder)
    { }

    // IERC20
    function totalSupply()
        external view
        returns (uint256)
    {
        return m_totalSupply;
    }

    // IERC20
    function balanceOf( address in_owner )
        external view
        returns (uint256)
    {
        require( in_owner == internal_msgSender() );

        return m_balances[in_owner];
    }

    function internal_mint( address in_who, uint256 in_value )
        internal
    {
        m_balances[in_who] += in_value;

        m_totalSupply += in_value;
    }

    function internal_burn( address in_who, uint256 in_value )
        internal
    {
        m_balances[in_who] -= in_value;

        m_totalSupply -= in_value;
    }

    function internal_transfer( address in_from, address in_to, uint256 in_value )
        internal
        returns (bool)
    {
        if( in_value == 0 || in_to == BURN_ADDRESS || in_to == address(0) ) {
            return false;
        }

        m_balances[in_from] -= in_value;

        m_balances[in_to] += in_value;

        return true;
    }

    // IERC20
    function transfer( address in_to, uint256 in_value )
        external
        returns (bool)
    {
        return internal_transfer(internal_msgSender(), in_to, in_value);
    }

    // IERC20
    function transferFrom( address in_from, address in_to, uint256 in_value )
        external
        returns (bool)
    {
        address sender = internal_msgSender();

        if( in_from != sender )
        {
            m_allowances.sub(in_from, sender, in_value);
        }

        return internal_transfer(in_from, in_to, in_value);
    }

    // IERC20
    function approve( address in_spender, uint256 in_value )
        external
        returns (bool)
    {
        m_allowances.set(internal_msgSender(), in_spender, in_value);

        return true;
    }

    // IERC20
    function allowance( address in_owner, address in_spender )
        external view
        returns (uint256)
    {
        address sender = internal_msgSender();

        require( in_owner == sender || in_spender == sender );

        return m_allowances.get(in_owner, in_spender);
    }

    function allowances( address who, uint256 in_offset, uint256 in_limit )
        internal view
        returns (uint256 out_count, address[] memory out_addrs, uint256[] memory out_values)
    {
        address sender = internal_msgSender();

        require( sender == who );

        (out_count, out_addrs, out_values) = m_allowances.list(sender, in_offset, in_limit);
    }
}
