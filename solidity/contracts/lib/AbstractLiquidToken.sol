// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC721ManyReceiver} from "../../../interfaces/IERC721.sol";
import {IBTCDeposit} from "../../../interfaces/IBTCDeposit.sol";
import {Sapphire} from "./sapphire/Sapphire.sol";
import {IERC165} from "../../../interfaces/IERC165.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IERC2771} from "../../../interfaces/IERC2771.sol";
import {IERC20Metadata} from "../../../interfaces/IERC20Metadata.sol";
import {IERC20Burnable} from "../../../interfaces/IERC20Burnable.sol";
import {IBtcMirror} from "../../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../../interfaces/IUsesBtcRelay.sol";
import {ILiquidToken} from "../../../interfaces/ILiquidToken.sol";
import {AbstractERC20} from "./AbstractERC20.sol";
import {Allowances} from "./Allowances.sol";


abstract contract AbstractLiquidToken is ILiquidToken, AbstractERC20
{
    using Allowances for Allowances.Data;

    mapping(uint256 => bytes32[]) private m_utxoBuckets;

    IBTCDeposit private immutable m_btcDeposit;

    constructor (IBTCDeposit in_btcDeposit, address in_2771Forwarder)
        AbstractERC20(in_2771Forwarder)
    {
        require( in_btcDeposit.supportsInterface(type(IBTCDeposit).interfaceId)
              && in_btcDeposit.supportsInterface(type(IUsesBtcRelay).interfaceId) );

        m_btcDeposit = in_btcDeposit;
    }

    // IERC165
    function supportsInterface(bytes4 interfaceId)
        external pure
        returns (bool)
    {
        return interfaceId == type(IUsesBtcRelay).interfaceId
            || interfaceId == type(IERC721ManyReceiver).interfaceId
            || interfaceId == type(ILiquidToken).interfaceId
            || interfaceId == type(IERC20).interfaceId
            || interfaceId == type(IERC20Metadata).interfaceId
            || interfaceId == type(IERC20Burnable).interfaceId
            || interfaceId == type(IERC165).interfaceId
            // IERC2771 comes via AbstractERC20
            // XXX: 'Linearization of inheritance graph impossible' with 'is IERC2771'
            // XXX: supportsInterface inheritence sucks in Solidity
            || interfaceId == type(IERC2771).interfaceId
            ;
    }

    // IUsesBtcRelay
    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_btcDeposit.getBtcRelay();
    }

    // AbstractLiquidToken
    function internal_getDenominationMask() virtual internal pure returns (uint256);

    // AbstractLiquidToken
    function internal_getChangeMask() virtual internal pure returns (uint256);

    // AbstractLiquidToken
    function internal_getDenominationBitCount() virtual internal pure returns (uint256);

    // ILiquidToken
    function getMinDenomination() virtual public pure returns (uint256);

    // ILiquidToken
    function getMaxDenomination() virtual public pure returns (uint256);

    function _isPowerOfTwo( uint256 u )
        internal pure
        returns (bool)
    {
        return (u & (u - 1)) == 0;
    }

    /// Deposits must be exact power of 2 within the denomination mask bit range
    /// Bits below the denomination mask are allowed (effectively ignored)
    /// No bits higher than the denomination mask can be set
    function internal_isValidDenomination( uint256 sats )
        internal pure
        returns (bool)
    {
        return _isPowerOfTwo(sats & internal_getDenominationMask())
            && ((sats & (internal_getChangeMask()|internal_getDenominationMask())) == sats);
    }

    // IERC721ManyReceiver
    /// Accept transfers from BTCDeposit contract, mint automatically
    function onERC721ReceivedMany(
        address /*in_operator*/,
        address in_from,
        bytes32[] calldata in_tokenId_list,
        bytes calldata in_data
    )
        external
        returns(bytes4)
    {
        require( internal_msgSender() == address(m_btcDeposit), "NOTMGR" );

        require( in_tokenId_list.length > 0, "NOTOKENS" );

        uint256[] memory in_sat_list = abi.decode(in_data, (uint256[]));

        uint256 mintSats;

        for( uint i = 0; i < in_sat_list.length; i++ )
        {
            uint256 sats = in_sat_list[i];

            require( internal_isValidDenomination(sats), "UTXO!=POW2+CHANGE" );

            // Change below the minimum denomination is quietly ignored
            uint256 bucket = sats & internal_getDenominationMask();

            mintSats += bucket;

            m_utxoBuckets[bucket].push(in_tokenId_list[i]);
        }

        require( mintSats > 0, "ZEROSATS" );

        internal_mint(in_from, mintSats);

        return IERC721ManyReceiver.onERC721ReceivedMany.selector;
    }

    /// Remove a random UTXO from the bucket (of the given denomination)
    function _popRandomUTXO( uint bucket )
        internal
        returns (bytes32)
    {
        bytes32[] storage utxos = m_utxoBuckets[bucket];

        uint len = utxos.length;

        require( len != 0, "EMPTYBUCKET" );

        // NOTE: avoid modulo bias, log2(rand) >= (2*log2(len))
        uint randIdx = uint64(bytes8(Sapphire.randomBytes(8, ""))) % len;

        bytes32 chosenKeypair = utxos[randIdx];

        if( randIdx != len-1 )
        {
            utxos[randIdx] = utxos[len-1];
        }

        utxos.pop();

        return chosenKeypair;
    }

    // IERC20Burnable
    /// Retrieve the UTXO count for each power-of-two bucket
    /// Buckets are specified as integers, e.g. 2**8, 2**16
    function getBucketCounts( uint[] calldata in_buckets )
        external view
        returns (uint256[] memory out)
    {
        out = new uint[](in_buckets.length);

        for( uint i = 0; i < in_buckets.length; i++ )
        {
            out[i] = m_utxoBuckets[in_buckets[i]].length;
        }
    }

    // IERC20Burnable
    function burn( uint256 value )
        external
    {
        withdraw(value);
    }

    // IERC20Burnable
    function burnFrom( address in_account, uint256 in_value )
        external
    {
        withdrawFrom(in_account, in_value);
    }

    // ILiquidToken
    function withdrawFrom( address in_account, uint in_sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        m_allowances.sub(in_account, internal_msgSender(), in_sats);

        return internal_withdraw(in_account, in_sats);
    }

    // ILiquidToken
    function withdraw( uint sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        return internal_withdraw(internal_msgSender(), sats);
    }

    /// Convert liquid token back into coins of underlying asset
    function internal_withdraw( address in_account, uint sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        // Withdrawing will output one coin per bit within the range
        require( (sats & internal_getDenominationMask()) == sats, "MASK!" );

        internal_burn(in_account, sats);

        out_utxoIdList = new bytes32[](internal_getDenominationBitCount());

        // Pay out one power of 2 token per bit in the input
        uint j = 0;

        for( uint i = getMinDenomination(); i <= getMaxDenomination(); i = i << 1 )
        {
            if( 0 != (sats & i) )
            {
                out_utxoIdList[j] = _popRandomUTXO(i);

                j += 1;
            }
        }

        // Reduce the list count to j (hacky..)
        assembly {
            mstore(out_utxoIdList, j)
        }

        // Transfer to msg.sender, to handle burnFrom/withdrawFrom etc.
        m_btcDeposit.safeTransferMany(internal_msgSender(), out_utxoIdList);
    }
}
