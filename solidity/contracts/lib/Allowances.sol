// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;


/// Manages allowances list
library Allowances {
    struct Inner {
        uint256 allowance;
        uint256 alloweeIndex;
    }

    struct Data {
        mapping(address => mapping(address => Inner)) allowances;

        mapping(address => address[]) allowees;
    }

    function get( Data storage self, address owner, address spender )
        internal view
        returns (uint256)
    {
        return self.allowances[owner][spender].allowance;
    }

    function has( Data storage self, address owner, address spender )
        internal view
        returns (bool)
    {
        address[] storage allowees = self.allowees[owner];

        if( allowees.length == 0 )
        {
            return false;
        }

        uint256 idx = self.allowances[owner][spender].alloweeIndex;

        if( allowees[idx] == spender )
        {
            return true;
        }

        return false;
    }

    function set( Data storage self, address owner, address spender, uint256 amount )
        internal
    {
        Inner storage x = self.allowances[owner][spender];

        x.allowance = amount;

        if( ! has(self, owner, spender) )
        {
            address[] storage y = self.allowees[owner];
            x.alloweeIndex = y.length;
            y.push(spender);
        }
    }

    function sub( Data storage self, address owner, address spender, uint256 amount )
        internal
    {
        self.allowances[owner][spender].allowance -= amount;
    }

    function list(
        Data storage self,
        address who,
        uint256 in_offset,
        uint256 in_limit
    )
        internal view
        returns (
            uint256 out_count,
            address[] memory out_addrs,
            uint256[] memory out_values
        )
    {
        address[] storage allowees = self.allowees[who];

        out_count = allowees.length;

        require( in_offset < out_count );

        if( (in_offset + in_limit) >= out_count )
        {
            in_limit = out_count - in_offset;
        }

        out_addrs = new address[](in_limit);

        out_values = new uint256[](in_limit);

        uint j = in_offset;

        mapping(address => Inner) storage inners = self.allowances[who];

        for( uint i = 0; i < in_limit; i++ )
        {
            address x = allowees[j];

            out_addrs[i] = x;

            out_values[i] = inners[x].allowance;

            j = j + 1;
        }
    }
}
