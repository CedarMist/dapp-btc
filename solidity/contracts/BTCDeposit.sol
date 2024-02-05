// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {ITxVerifier} from "../../interfaces/ITxVerifier.sol";
import {BtcTxProof} from "../../interfaces/BtcTxProof.sol";
import {Sapphire} from "./lib/sapphire/Sapphire.sol";
import {EthereumUtils} from "./lib/sapphire/EthereumUtils.sol";
import {EthereumUtils} from "./lib/sapphire/EthereumUtils.sol";
import {BTCUtils} from "./lib/BTCUtils.sol";

import {IERC721ManyReceiver} from "../../interfaces/IERC721.sol";
import {IBtcMirror} from "../../interfaces/IBtcMirror.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IBTCDeposit} from "../../interfaces/IBTCDeposit.sol";
import {IUsesBtcRelay} from "../../interfaces/IUsesBtcRelay.sol";


contract BTCDeposit is IERC165, IUsesBtcRelay, IBTCDeposit {

    /// Master keys used to derive keypairs are rotated daily
    uint256 constant private DERIVE_KEY_ROTATION = (60*60*24);

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

    struct DerivingMasterKey {
        uint256 timestamp;
        bytes32 secret;
    }


    // -------------------------------------------------------------------------


    ITxVerifier private immutable m_verifier;

    IBtcMirror private immutable m_mirror;

    mapping(uint256 => DerivingMasterKey) private m_deriving_keys;

    uint256 private m_derive_epoch;

    mapping(bytes32 => Keypair) private m_keypairs;


    // -------------------------------------------------------------------------


    constructor( ITxVerifier in_verifier )
    {
        require(in_verifier.supportsInterface(type(ITxVerifier).interfaceId)
             && in_verifier.supportsInterface(type(IUsesBtcRelay).interfaceId),
                "ERC165!" );

        m_verifier = in_verifier;

        m_mirror = in_verifier.getBtcRelay();

        internal_rotateDerivingKey();
    }


    function getBtcRelay()
        external view override
        returns (IBtcMirror)
    {
        return m_verifier.getBtcRelay();
    }


    function supportsInterface( bytes4 interfaceId )
        external pure
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IBTCDeposit).interfaceId
            || interfaceId == type(IUsesBtcRelay).interfaceId;
    }

    // -------------------------------------------------------------------------

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
        (out_pubkeyAddress, out_keypairId) = createDerived(in_owner, m_derive_epoch, bytes32(Sapphire.randomBytes(32, "")));
    }

    // -------------------------------------------------------------------------

    /**
     * Internal keys are used to derive keys, the seed must be combined with
     * user input at the time of creation so getting access to the keys won't
     * reveal the subkeys.
     */
    function internal_rotateDerivingKey ()
        internal
    {
        uint256 derive_epoch = m_derive_epoch;

        if( m_deriving_keys[derive_epoch].timestamp < (block.timestamp - DERIVE_KEY_ROTATION) )
        {
            derive_epoch += 1;

            m_derive_epoch = derive_epoch;

            m_deriving_keys[derive_epoch] = DerivingMasterKey({
                timestamp: block.timestamp,
                secret: bytes32(Sapphire.randomBytes(32, ""))
            });
        }
    }

    // -------------------------------------------------------------------------

    function internal_derive(
        address in_owner,
        uint256 in_derive_epoch,
        bytes32 in_derive_seed
    )
        internal view
        returns (bytes32 out_secret, bytes20 out_pubkeyAddress, bytes32 out_keypairId)
    {
        DerivingMasterKey memory dk = m_deriving_keys[in_derive_epoch];

        require( dk.timestamp != 0 );

        out_secret = keccak256(abi.encodePacked(dk.secret, in_derive_seed, in_owner, dk.secret));

        (bytes memory pubkey, ) = Sapphire.generateSigningKeyPair(
            Sapphire.SigningAlg.Secp256k1PrehashedSha256,
            abi.encodePacked(out_secret)
        );

        out_pubkeyAddress = BTCUtils.btcAddress(pubkey);

        out_keypairId = keccak256(abi.encodePacked(out_secret, out_pubkeyAddress));
    }

    // -------------------------------------------------------------------------

    function createDerivedWithoutEpoch (
        address in_owner,
        bytes32 in_derive_seed
    )
        public
        returns (
            bytes20 out_pubkeyAddress,
            bytes32 out_keypairId,
            uint256 out_epoch
        )
    {
        out_epoch = m_derive_epoch;

        (out_pubkeyAddress, out_keypairId) = createDerived(in_owner, out_epoch, in_derive_seed);
    }

    // -------------------------------------------------------------------------

    function createDerived (
        address in_owner,
        uint256 in_derive_epoch,
        bytes32 in_derive_seed
    )
        public
        returns (bytes20 out_pubkeyAddress, bytes32 out_keypairId)
    {
        bytes32 secret;

        (secret, out_pubkeyAddress, out_keypairId) = internal_derive(in_owner, in_derive_epoch, in_derive_seed);

        m_keypairs[out_keypairId] = Keypair({
            secret: secret,
            btcAddress: out_pubkeyAddress,
            owner: in_owner,
            deposit: DepositInfo({
                burnHeight: 0,
                sats: 0,
                blockNum: 0,
                txOutIx: 0
            })
        });

        internal_rotateDerivingKey();
    }

    // -------------------------------------------------------------------------

    function derive( address in_owner, bytes32 in_derive_seed )
        external view
        returns (bytes20 out_pubkeyAddress, bytes32 out_keypairId, uint256 out_derive_epoch)
    {
        out_derive_epoch = m_derive_epoch;

        (, out_pubkeyAddress, out_keypairId) = internal_derive(in_owner, out_derive_epoch, in_derive_seed);
    }

    // -------------------------------------------------------------------------

    function depositDerived(
        address in_owner,
        uint256 in_derive_epoch,
        bytes32 in_derive_seed,
        uint32 in_blockNum,
        BtcTxProof calldata in_inclusionProof,
        uint32 in_txOutIx,
        bytes32 in_keypairId
    )
        external
        returns (uint64 out_sats)
    {
        (,bytes32 tmp_keypairId) = createDerived(in_owner, in_derive_epoch, in_derive_seed);

        require( tmp_keypairId == in_keypairId );

        return deposit(in_blockNum, in_inclusionProof, in_txOutIx, in_keypairId);
    }

    // -------------------------------------------------------------------------

    function deposit(
        uint32 blockNum,
        BtcTxProof calldata inclusionProof,
        uint32 txOutIx,
        bytes32 keypairId
    )
        public
        returns (uint64 out_sats)
    {
        Keypair storage kp_storage = m_keypairs[keypairId];

        Keypair memory kp_mem = kp_storage;

        // Keypair must exist
        require( kp_mem.btcAddress != bytes20(0), "404" );

        // Must not have been burned
        // If the secret has been revealed, the contract cannot be said to have custody
        require( kp_mem.deposit.burnHeight == 0, "BURNED" );

        // Keypairs can only be used once
        require( kp_mem.deposit.blockNum == 0, "ONCE" );

        bytes20 actualPubkeyHash;

        (actualPubkeyHash, out_sats) = m_verifier.verifiedP2PKHPayment(
            m_mirror.getMinConfirmations(),
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

    // -------------------------------------------------------------------------

    /**
     * Marks a keypair as burned, so that its secret can be recoved in the next block
     * @param in_keypairId Unique keypair ID
     */
    function burn(bytes32 in_keypairId)
        external
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( kp.owner == msg.sender, "NOTOWNER" );

        kp.deposit.burnHeight = uint64(block.number);
    }

    // -------------------------------------------------------------------------

    /**
     * Deletes the keypair from storage, forever forgetting its secret
     *
     * @param in_keypairId Unique keypair ID
     */
    function purge(bytes32 in_keypairId)
        external
    {
        Keypair storage kp = m_keypairs[in_keypairId];

        require( kp.owner == msg.sender, "NOTOWNER" );

        delete m_keypairs[in_keypairId];
    }

    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------

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
