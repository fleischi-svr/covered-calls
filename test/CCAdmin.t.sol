// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./TestERC721.sol";
import "../src/CCAdmin.sol";


contract ContractTest is Test {
    CCAdmin public ccAdmin;
    TestERC721 public nft;
    address public optionCreator;
    address public optionBuyer;
    address public optionBuyer2;

    function setUp() public {
        ccAdmin = new CCAdmin();
        nft = new TestERC721();
        optionCreator = address(5);
        optionBuyer = address(6);
        optionBuyer2 = address(6);
        vm.deal(optionCreator, 3 ether);
        vm.deal(optionBuyer, 3 ether);
        vm.deal(optionBuyer2, 3 ether);
        nft.mint(optionCreator,1);
    }

    function testFailOptionTokenNOwned() public {
        vm.prank(optionCreator);
        vm.expectRevert(bytes("caller must own given token"));
        uint256 optID = ccAdmin.createOption(300000000000000000, 100, 300, 2000000000000000000, 2, address(nft));
    }

    function testCreateOption() public {
        vm.prank(optionCreator);
        uint256 optID = ccAdmin.createOption(300000000000000000, 100, 300, 2000000000000000000, 1, address(nft));
        assertEq(optID,0);
    }

    function testFailBuyOpInvalidOptionTime() public{
        vm.warp(200);
        vm.expectRevert(bytes("option already expired"));
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }
    function testFailBuyOpInvalidOptionSold() public{
        vm.prank(optionBuyer);
        ccAdmin.buyOption{value: 300000000000000000}(1);
        vm.expectRevert(bytes("option already sold"));
        vm.prank(optionBuyer2);
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }

    function testFailBuyOpMsgValueNPremium() public{
        vm.prank(optionBuyer);
        vm.expectRevert(bytes("value != premium"));
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }


}
