// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "../../../interfaces/IERC165.sol";
import {IBtcMirror} from "../../../interfaces/IBtcMirror.sol";
import {IUsesBtcRelay} from "../../../interfaces/IUsesBtcRelay.sol";
import {Endian} from "./Endian.sol";


abstract contract AbstractRelay is IERC165, IBtcMirror, IUsesBtcRelay {
    // -------------------------------------------------------------------------
    // STRUCTS

    struct BlockHeader {
        bytes32 previousblockhash;
        bytes32 merkleroot;
        uint32 version;
        uint32 time;
        uint32 bits;
        uint32 nonce;
    }

    struct PackedStatus {
        uint32 time;
        uint32 height;
    }

    // -------------------------------------------------------------------------
    // PRIVATE STORAGE

    mapping(uint256 => bytes32) internal m_heightToHash;

    PackedStatus internal m_status;


    // -------------------------------------------------------------------------
    // PUBLIC STORAGE

    bool immutable public isTestnet;

    uint256 immutable public startHeight;

    function _checkRetarget(uint256 currentHeight, uint256 target) internal virtual;


    // -------------------------------------------------------------------------
    // CONSTRUCTOR

    constructor(
        bytes32 in_blockHash,
        uint256 in_blockHeight,
        uint32 in_time,
        bool in_isTestnet
    )
    {
        startHeight = in_blockHeight;

        m_status = PackedStatus({
            time: in_time,
            height: uint32(in_blockHeight)
        });

        m_heightToHash[in_blockHeight] = in_blockHash;

        isTestnet = in_isTestnet;
    }

    // -------------------------------------------------------------------------
    // EXTERNAL INTERFACE

    function supportsInterface(bytes4 interfaceId)
        external pure
        returns (bool)
    {
        return interfaceId == this.getBlockHashReversed.selector
            || interfaceId == type(IBtcMirror).interfaceId
            || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IUsesBtcRelay).interfaceId;
    }

    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return this;
    }

    /**
     * @notice Returns the (reversed) Bitcoin block hash at a specific height.
     */
    function getBlockHash(uint256 in_height)
        public view
        returns (bytes32)
    {
        return bytes32(Endian.reverse256(uint256(getBlockHashReversed(in_height))));
    }

    /**
     * @notice Returns the (reversed) Bitcoin block hash at a specific height.
     */
    function getBlockHashReversed(uint256 in_height)
        public view
        returns (bytes32)
    {
        if( in_height < startHeight )
        {
            require(false, "START_HEIGHT");
        }

        if( in_height > m_status.height )
        {
            require(false, "INVALID_HEIGHT");
        }

        return m_heightToHash[in_height];
    }

    /** @notice Returns the height of the latest block (tip of the chain). */
    function getLatestBlockHeight()
        external view
        returns (uint256)
    {
        return m_status.height;
    }

    /** @notice Returns the timestamp of the lastest block, as Unix seconds. */
    function getLatestBlockTime()
        external view
        returns (uint256)
    {
        return m_status.time;
    }


    // -------------------------------------------------------------------------
    // PUBLIC FUNCTIONS

    function submit(uint256 in_height, BlockHeader[] calldata in_headers)
        external
    {
        unchecked {
            if( in_height <= startHeight )
            {
                require(false, "START_HEIGHT");
            }

            if(in_headers.length == 0)
            {
                require(false, "NO_HEADERS");
            }

            // Verify new headers continue from existing chain
            if(in_headers[0].previousblockhash != m_heightToHash[in_height - 1])
            {
                require(false, "NOT_IN_SEQUENCE");
            }

            uint256 new_height = in_height + in_headers.length;

            // Cumulative proof of work of the active fork we propose to replace
            // (lower = more proof of work)
            uint256 cumulativeWork_main = 0;
            {
                uint256 main_height = m_status.height;

                for( uint i = in_height; i <= main_height; i++ )
                {
                    cumulativeWork_main += Endian.reverse256(uint256(m_heightToHash[i]));

                    if( i >= new_height )
                    {
                        delete m_heightToHash[i];
                    }
                }
            }

            bytes32 prevBlockHash;

            uint256 cumulativeWork_thisFork = 0;

            uint256 latestTime;

            for( uint i = 0; i < in_headers.length; i++ )
            {
                BlockHeader calldata currentHeader = in_headers[i];
                uint256 currentHeight = in_height + i;
                bytes32 currentHash = BlockHeader_hash(currentHeader);

                latestTime = currentHeader.time;

                // Verify the headers submitted are a sequential hash chain
                if( i > 0 )
                {
                    if( currentHeader.previousblockhash != prevBlockHash )
                    {
                        require(false, "NOT_HASH_CHAIN");
                    }
                }

                prevBlockHash = currentHash;

                uint256 target = nBitsToTarget(currentHeader.bits);

                // Check proof of work meets target
                // and Keep track of cumulative PoW for replacement chain
                {
                    uint256 blockHash_swapped = Endian.reverse256(uint256(currentHash));

                    cumulativeWork_thisFork += blockHash_swapped;

                    if( blockHash_swapped > target )
                    {
                        require(false, "POW_NOT_MET");
                    }
                }

                // Bitcoin retargeting works differently from LTC and Dogecoin
                _checkRetarget(currentHeight, target);

                m_heightToHash[currentHeight] = currentHash;
            }

            // When replacing blocks, ensure the cumulative PoW of the replacement
            // is greater than that of the squence of blocks being replaced.
            if( cumulativeWork_main != 0 )
            {
                if( cumulativeWork_thisFork >= cumulativeWork_main )
                {
                    require(false, "REORG_UNDER_POWERED");
                }
            }

            m_status = PackedStatus({
                time: uint32(latestTime),
                height: uint32(new_height - 1)
            });
        }
    }


    // -------------------------------------------------------------------------
    // HELPER FUNCTIONS

    /*
    * @notice Performs Bitcoin-like double sha256
    * @param data Bytes to be flipped and double hashed s
    */
    function dblSha(bytes memory data)
        internal pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(sha256(data)));
    }

    /*
    * @notice Calculates the PoW difficulty target from compressed nBits representation,
    * according to https://developer.bitcoin.org/reference/block_chain.html#target-nbits
    * @param nBits Compressed PoW target representation
    * @return PoW difficulty target computed from nBits
    */
    function nBitsToTarget(uint256 nBits)
        internal pure
        returns (uint256)
    {
        unchecked {
            uint256 exp = nBits >> 24;
            uint256 c = nBits & 0xffffff;
            uint256 target = uint256((c * 2**(8*(exp - 3))));
            return target;
        }
    }

    function BlockHeader_hash(BlockHeader calldata h)
        internal pure
        returns (bytes32 out_blockHash)
    {
        out_blockHash = dblSha(abi.encodePacked(
            Endian.reverse32(h.version),  // Not required in storage
            h.previousblockhash,
            h.merkleroot,
            Endian.reverse32(h.time), // Required in storage
            Endian.reverse32(h.bits), // Required in storage
            Endian.reverse32(h.nonce) // Not required in storage
        ));
    }
}
