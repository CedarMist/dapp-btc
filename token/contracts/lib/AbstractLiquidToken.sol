// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {IERC721ManyReceiver} from "../../../interfaces/IERC721.sol";
import {IBTCDeposit} from "../../../interfaces/IBTCDeposit.sol";
import {Sapphire} from "./Sapphire.sol";
import {IERC165} from "../../../interfaces/IERC165.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IERC20Metadata} from "../../../interfaces/IERC20Metadata.sol";
import {IERC20Burnable} from "../../../interfaces/IERC20Burnable.sol";
import {IBtcMirror} from "../../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../../interfaces/IUsesBtcRelay.sol";
import {AbstractERC20} from "./AbstractERC20.sol";


abstract contract AbstractLiquidToken is IERC721ManyReceiver, IERC165, IUsesBtcRelay, IERC20Burnable, AbstractERC20
{
    mapping(uint256 => bytes32[]) private m_utxoBuckets;

    IBTCDeposit private immutable m_manager;

    constructor (IBTCDeposit in_manager)
    {
        require( in_manager.supportsInterface(type(IBTCDeposit).interfaceId)
              && in_manager.supportsInterface(type(IUsesBtcRelay).interfaceId) );

        m_manager = in_manager;
    }

    // IERC165
    function supportsInterface(bytes4 interfaceId)
        external pure
        returns (bool)
    {
        return interfaceId == type(IUsesBtcRelay).interfaceId
            || interfaceId == type(IERC721ManyReceiver).interfaceId
            || interfaceId == type(IERC20).interfaceId
            || interfaceId == type(IERC20Metadata).interfaceId
            || interfaceId == type(IERC20Burnable).interfaceId
            || interfaceId == type(IERC165).interfaceId
            ;
    }

    // IUsesBtcRelay
    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_manager.getBtcRelay();
    }

    function _isPowerOfTwo( uint256 u )
        internal pure
        returns (bool)
    {
        return (u & (u - 1)) == 0;
    }

    function _getDenominationMask() virtual internal pure returns (uint256);
    function _getChangeMask() virtual internal pure returns (uint256);
    function _getDenominationBitCount() virtual internal pure returns (uint256);
    function getMinDenomination() virtual public pure returns (uint256);
    function getMaxDenomination() virtual public pure returns (uint256);

    /// Deposits must be exact power of 2 within the denomination mask bit range
    /// Bits below the denomination mask are allowed (effectively ignored)
    /// No bits higher than the denomination mask can be set
    function _isValidDenomination( uint256 sats )
        internal pure
        returns (bool)
    {
        return _isPowerOfTwo(sats & _getDenominationMask())
            && ((sats & (_getChangeMask()|_getDenominationMask())) == sats);
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
        require( msg.sender == address(m_manager), "NOTMGR" );

        require( in_tokenId_list.length > 0, "NOTOKENS" );

        uint256[] memory in_sat_list = abi.decode(in_data, (uint256[]));

        uint256 mintSats;

        for( uint i = 0; i < in_sat_list.length; i++ )
        {
            uint256 sats = in_sat_list[i];

            require( _isValidDenomination(sats), "UTXO!=POW2+CHANGE" );

            uint256 bucket = sats & _getDenominationMask();

            // Change below the minimum denomination is quietly ignored
            mintSats += bucket;

            m_utxoBuckets[bucket].push(in_tokenId_list[i]);
        }

        require( mintSats > 0, "ZEROSATS" );

        _mint(in_from, mintSats);

        return IERC721ManyReceiver.onERC721ReceivedMany.selector;
    }

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

    function withdrawFrom( address in_account, uint in_sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        m_allowances[in_account][msg.sender] -= in_sats;

        return internal_withdraw(in_account, in_sats);
    }

    function withdraw( uint sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        return internal_withdraw(msg.sender, sats);
    }

    function internal_withdraw( address in_account, uint sats )
        public
        returns (bytes32[] memory out_utxoIdList)
    {
        require( (sats & _getDenominationMask()) == sats, "MASK!" );

        _burn(in_account, sats);

        out_utxoIdList = new bytes32[](_getDenominationBitCount());

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
        m_manager.safeTransferMany(msg.sender, out_utxoIdList);
    }
}
