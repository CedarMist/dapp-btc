// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IERC721ManyReceiver {
    function onERC721ReceivedMany(address _operator, address _from, bytes32[] calldata _tokenId, bytes calldata _data) external returns(bytes4);
}
