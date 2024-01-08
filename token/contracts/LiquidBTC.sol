// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721ManyReceiver} from "../../interfaces/IERC721.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {Sapphire} from "./lib/Sapphire.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IERC20Burnable} from "../../interfaces/IERC20Burnable.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";
import {AbstractERC20} from "./lib/AbstractERC20.sol";


contract LiquidBTC is IERC721ManyReceiver, IERC165, IUsesBtcRelay, IERC20Metadata, IERC20Burnable, AbstractERC20
{
    // Denominations are powers of 2, we allow 15 unique denominations
    // Values below the minimum denomination are 'change' or 'dust' and are ignored
    uint256 constant private MIN_SHL = 13;
    uint256 constant private MAX_SHL = 27;
    uint256 constant private MIN_DENOMINATION = 1<<MIN_SHL;                                 // 0.00008192 BTC,               0b10000000000000,    0x2000
    uint256 constant private MAX_DENOMINATION = 1<<MAX_SHL;                                 // 1.34217728 BTC, 0b1000000000000000000000000000, 0x8000000
    uint256 constant private CHANGE_MASK = MIN_DENOMINATION-1;                              // 0.00008191 BTC,                0b1111111111111,    0x1fff
    uint256 constant private DENOMINATION_MASK = ((MAX_DENOMINATION<<1)-1) ^ CHANGE_MASK;   // 2.68427264 BTC, 0b1111111111111110000000000000, 0xfffe000
    uint256 constant private DENOM_MASK_BIT_COUNT = (MAX_SHL+1)-MIN_SHL;                    // 15 == bin(DENOMINATION_MASK).count('1')

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

    // IERC20Metadata
    function name()
        external pure
        returns (string memory)
    {
        return "Liquid BTC";
    }

    // IERC20Metadata
    function symbol()
        external pure
        returns (string memory)
    {
        return "liquidBTC";
    }

    // IERC20Metadata
    function decimals()
        external pure
        returns (uint8)
    {
        return 8;
    }

    function _isPowerOfTwo( uint256 u )
        internal pure
        returns (bool)
    {
        return (u & (u - 1)) == 0;
    }

    /// Deposits must be exact power of 2 within the denomination mask bit range
    /// Bits below the denomination mask are allowed (effectively ignored)
    /// No bits higher than the denomination mask can be set
    function _isValidDenomination( uint256 sats )
        internal pure
        returns (bool)
    {
        return _isPowerOfTwo(sats & DENOMINATION_MASK)
            && ((sats & (CHANGE_MASK|DENOMINATION_MASK)) == sats);
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

            uint256 bucket = sats & DENOMINATION_MASK;

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
        require( (sats & DENOMINATION_MASK) == sats, "MASK!" );

        _burn(in_account, sats);

        out_utxoIdList = new bytes32[](DENOM_MASK_BIT_COUNT);

        // Pay out one power of 2 token per bit in the input
        uint j = 0;

        for( uint i = MIN_DENOMINATION; i <= MAX_DENOMINATION; i = i << 1 )
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
