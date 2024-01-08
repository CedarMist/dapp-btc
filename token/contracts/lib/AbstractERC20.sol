// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "../../../interfaces/IERC20.sol";

abstract contract AbstractERC20 is IERC20
{
    address constant internal BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 internal m_totalSupply;

    mapping(address => uint256) internal m_balances;

    mapping(address => mapping(address => uint256)) internal m_allowances;

    function totalSupply()
        external view
        returns (uint256)
    {
        return m_totalSupply;
    }

    function balanceOf( address in_owner )
        external view
        returns (uint256)
    {
        return m_balances[in_owner];
    }

    function _mint( address in_who, uint256 in_value)
        internal
    {
        m_balances[in_who] += in_value;

        m_totalSupply += in_value;

        emit Transfer(BURN_ADDRESS, in_who, in_value);
    }

    function _burn( address in_who, uint256 in_value )
        internal
    {
        m_balances[in_who] -= in_value;

        m_totalSupply -= in_value;

        emit Transfer(in_who, BURN_ADDRESS, in_value);
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

        emit Transfer(in_from, in_to, in_value);

        return true;
    }

    function transfer(address in_to, uint256 in_value)
        external
        returns (bool)
    {
        return internal_transfer(msg.sender, in_to, in_value);
    }

    function transferFrom(address in_from, address in_to, uint256 in_value)
        external
        returns (bool)
    {
        if( in_from != msg.sender )
        {
            m_allowances[in_from][msg.sender] -= in_value;
        }

        return internal_transfer(in_from, in_to, in_value);
    }

    function approve(address in_spender, uint256 in_value)
        external
        returns (bool)
    {
        m_allowances[msg.sender][in_spender] = in_value;

        emit Approval(msg.sender, in_spender, in_value);

        return true;
    }

    function allowance(address in_owner, address in_spender)
        external view
        returns (uint256)
    {
        return m_allowances[in_owner][in_spender];
    }
}