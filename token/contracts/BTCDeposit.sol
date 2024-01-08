// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBtcTxVerifier} from "../../interfaces/IBtcTxVerifier.sol";
import {BtcTxProof} from "../../interfaces/BtcTxProof.sol";
import {Sapphire} from "./lib/Sapphire.sol";

import {IERC721ManyReceiver} from "../../interfaces/IERC721.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";


contract BTCDeposit is IERC165, IUsesBtcRelay, IBTCDeposit {
    uint private constant MIN_CONFIRMATIONS = 6;

    // This struct can be packed into a single 256bit field
    struct DepositInfo {
        uint64 burnHeight;
        uint64 sats;
        uint32 blockNum;
        uint32 txOutIx;
    }

    struct Keypair {
        bytes32 secret;
        bytes20 btcAddress;
        address owner;
        DepositInfo deposit;
    }

    IBtcTxVerifier private immutable m_verifier;

    mapping(bytes32 => Keypair) private m_keypairs;

    constructor( IBtcTxVerifier in_verifier )
    {
        require(in_verifier.supportsInterface(type(IBtcTxVerifier).interfaceId)
             && in_verifier.supportsInterface(type(IUsesBtcRelay).interfaceId),
             "in_verifier!" );

        m_verifier = in_verifier;
    }

    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_verifier.getBtcRelay();
    }

    function supportsInterface(bytes4 interfaceId)
        external pure
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IBTCDeposit).interfaceId
            || interfaceId == type(IUsesBtcRelay).interfaceId;
    }

    /**
     * Create contract-managed keypairs, the public address is only returned
     * upon creation so it's unwise to call this directly as you'll not know
     * where to deposit suff.
     *
     * After creation the only information that can be retrieved is via getMeta
     * which includes the value deposited and whether or not the secret has been
     * revealed to the owner.
     *
     * @param in_owner Beneficial owner of the keypair
     * @return out_pubkeyAddress Raw 160 bit public address
     * @return out_keypairId Unique keypair ID (unlinkable to address without the secret)
     */
    function create( address in_owner )
        external
        returns (bytes20 out_pubkeyAddress, bytes32 out_keypairId)
    {
        bytes memory secret = Sapphire.randomBytes(32, "");

        (bytes memory pubkey,) = Sapphire.generateKeypair(secret);

        out_pubkeyAddress = Sapphire.btcAddress(pubkey);

        // Obfuscate the keypair ID, unlinkable without its secret key
        out_keypairId = keccak256(abi.encodePacked(secret, out_pubkeyAddress));

        m_keypairs[out_keypairId] = Keypair({
            secret: bytes32(secret),
            btcAddress: out_pubkeyAddress,
            owner: in_owner,
            deposit: DepositInfo({
                burnHeight: 0,
                sats: 0,
                blockNum: 0,
                txOutIx: 0
            })
        });
    }

    function deposit(
        uint32 blockNum,
        BtcTxProof calldata inclusionProof,
        uint32 txOutIx,
        bytes32 keypairId
    )
        external
        returns (uint64 out_sats)
    {
        Keypair storage kp_storage = m_keypairs[keypairId];

        Keypair memory kp_mem = kp_storage;

        // Keypair must exist
        require( kp_mem.btcAddress != bytes20(0), "404" );

        // Must not have been burned
        require( kp_mem.deposit.burnHeight == 0, "BURNED" );

        // Keypairs can only be used once
        require( kp_mem.deposit.blockNum == 0, "ONCE" );

        bytes20 actualPubkeyHash;

        (actualPubkeyHash, out_sats) = m_verifier.verifiedP2PKHPayment(
            MIN_CONFIRMATIONS,
            blockNum,
            inclusionProof,
            txOutIx
        );

        require( actualPubkeyHash == kp_mem.btcAddress, "WRONG_RECIPIENT" );

        kp_storage.deposit = DepositInfo({
            burnHeight: 0,
            sats: out_sats,
            blockNum: blockNum,
            txOutIx: txOutIx
        });
    }

    function burn(bytes32 in_keypairId)
        external
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( kp.owner == msg.sender, "NOTOWNER" );

        kp.deposit.burnHeight = uint64(block.number);
    }

    function purge(bytes32 in_keypairId)
        external
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( kp.owner == msg.sender, "NOTOWNER" );

        delete m_keypairs[in_keypairId];
    }

    function getSecret(bytes32 in_keypairId)
        external view
        returns (bytes20 out_btcAddress, bytes32 out_secret)
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( kp.owner == msg.sender, "NOTOWNER" );

        // Must wait at least 1 block before revealing secret
        // SECURITY: this is required to prevent revert() attacks
        require( block.number > kp.deposit.burnHeight );

        out_btcAddress = kp.btcAddress;

        out_secret = kp.secret;
    }

    function getMeta(bytes32 in_keypairId)
        external view
        returns (uint64 out_burnHeight, uint64 out_sats)
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( msg.sender == kp.owner, "NOTOWNER" );

        DepositInfo memory di = kp.deposit;

        out_burnHeight = di.burnHeight;

        out_sats = di.sats;
    }

    function safeTransferMany(address in_to, bytes32[] calldata in_keypairId_list)
        external
    {
        require( in_to != address(0), "403" );

        require( in_keypairId_list.length > 0, "400" );

        uint[] memory sats = new uint[](in_keypairId_list.length);

        address prevOwner;

        for( uint i = 0; i < in_keypairId_list.length; i++ )
        {
            bytes32 keypairId = in_keypairId_list[i];

            Keypair storage kp = m_keypairs[keypairId];

            prevOwner = kp.owner;

            require( prevOwner == msg.sender, "401" );

            DepositInfo memory di = kp.deposit;

            // Cannot transfer burned keypairs
            require( di.burnHeight == 0, "410" );

            kp.owner = in_to;

            sats[i] = di.sats;
        }

        bytes memory data = abi.encode(sats);

        _checkOnERC721ReceivedMany(prevOwner, in_to, in_keypairId_list, data);
    }

    error ERC721InvalidReceiver(address receiver);

    function _checkOnERC721ReceivedMany(
        address in_from,
        address in_to,
        bytes32[] calldata in_tokenId_list,
        bytes memory in_data
    )
        private
    {
        if (in_to.code.length > 0) {
            try IERC721ManyReceiver(in_to).onERC721ReceivedMany(msg.sender, in_from, in_tokenId_list, in_data) returns (bytes4 retval) {
                if (retval != IERC721ManyReceiver.onERC721ReceivedMany.selector) {
                    revert ERC721InvalidReceiver(in_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(in_to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}
