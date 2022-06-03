// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721("TestERC721", "TEST") {
    function mint(address to, uint256 id) external {
        super._mint(to, id);
    }

    function approveAllFor(address owner, address operator) external {
        super._setApprovalForAll(owner, operator, true);
    }
}