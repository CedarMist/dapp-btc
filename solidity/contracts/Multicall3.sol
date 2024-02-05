// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract Multicall3 {
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    string public constant SIGNIN_TYPE = "SignIn(string grantAccessTo,address signer,uint256 notBefore,uint256 expiresAt)";
    bytes32 public constant SIGNIN_TYPEHASH = keccak256(bytes(SIGNIN_TYPE));

    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256("IX.ChainSession"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    struct Call {
        address target;
        bytes callData;
    }

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct SignatureRSV {
        bytes32 r;
        bytes32 s;
        uint256 v;
    }

    struct Signature {
        address signer;
        uint256 notBefore;
        uint256 expiresAt;
        SignatureRSV rsv;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function _extractValidSigner(Signature calldata signature) private view returns (address) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                SIGNIN_TYPEHASH,
                keccak256("https://ix.exchange/wallet"),
                signature.signer,
                signature.notBefore,
                signature.expiresAt
            ))
        ));

        address recoveredAddress = ecrecover(digest, uint8(signature.rsv.v), signature.rsv.r, signature.rsv.s);
        require(recoveredAddress == signature.signer, "Invalid signature");
        require(signature.expiresAt >= block.timestamp && signature.notBefore < block.timestamp, "Signature expired");

        return signature.signer;
    }

    function _aggregate(Call[] calldata calls, address _sender) private returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            bool success;
            call = calls[i];
            (success, returnData[i]) = call.target.call(abi.encodePacked(call.callData, _sender));
            require(success, "Multicall3: call failed");
            unchecked {++i;}
        }
    }

    function aggregate(Call[] calldata calls) public payable returns (uint256 blockNumber, bytes[] memory returnData) {
        return _aggregate(calls, msg.sender);
    }

    function aggregateSigned(Call[] calldata calls, Signature calldata signature) public payable returns (uint256 blockNumber, bytes[] memory returnData) {
        return _aggregate(calls, _extractValidSigner(signature));
    }

    function _tryAggregate(bool requireSuccess, Call[] calldata calls, address _sender) private returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            call = calls[i];
            (result.success, result.returnData) = call.target.call(abi.encodePacked(call.callData, _sender));
            if (requireSuccess) require(result.success, "Multicall3: call failed");
            unchecked {++i;}
        }
    }

    function tryAggregate(bool requireSuccess, Call[] calldata calls) public payable returns (Result[] memory returnData) {
        return _tryAggregate(requireSuccess, calls, msg.sender);
    }

    function tryAggregateSigned(bool requireSuccess, Call[] calldata calls, Signature calldata signature) public payable returns (Result[] memory returnData) {
        return _tryAggregate(requireSuccess, calls, _extractValidSigner(signature));
    }

    function tryBlockAndAggregate(bool requireSuccess, Call[] calldata calls) public payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        blockNumber = block.number;
        blockHash = blockhash(block.number);
        returnData = tryAggregate(requireSuccess, calls);
    }

    function blockAndAggregate(Call[] calldata calls) public payable returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(true, calls);
    }

    function _aggregate3(Call3[] calldata calls, address _sender) private returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3 calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(abi.encodePacked(calli.callData, _sender));
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x64)
                }
            }
            unchecked { ++i; }
        }
    }

    function aggregate3(Call3[] calldata calls) public payable returns (Result[] memory returnData) {
        return _aggregate3(calls, msg.sender);
    }

    function aggregate3Signed(Call3[] calldata calls, Signature calldata signature) public payable returns (Result[] memory returnData) {
        return _aggregate3(calls, _extractValidSigner(signature));
    }

    function _aggregate3Value(Call3Value[] calldata calls, address _sender) private returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked { valAccumulator += val; }
            (result.success, result.returnData) = calli.target.call{value: val}(abi.encodePacked(calli.callData, _sender));
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x84)
                }
            }
            unchecked { ++i; }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "Multicall3: value mismatch");
    }

    function aggregate3Value(Call3Value[] calldata calls) public payable returns (Result[] memory returnData) {
        return _aggregate3Value(calls, msg.sender);
    }

    function aggregate3ValueSigned(Call3Value[] calldata calls, Signature calldata signature) public payable returns (Result[] memory returnData) {
        return _aggregate3Value(calls, _extractValidSigner(signature));
    }

    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    function getCurrentBlockDifficulty() public view returns (uint256 difficulty) {
        difficulty = block.difficulty;
    }

    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }

    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    function getLastBlockHash() public view returns (bytes32 blockHash) {
        unchecked {
            blockHash = blockhash(block.number - 1);
        }
    }

    function getBasefee() public view returns (uint256 basefee) {
        basefee = block.basefee;
    }

    function getChainId() public view returns (uint256 chainid) {
        chainid = block.chainid;
    }
}
