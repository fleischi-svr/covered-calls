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
    }

    // Test Create Option
    // check 4 not owned NFT => OK
    function testFailOptionTokenNOwned() public {
        vm.prank(optionCreator);
        vm.expectRevert(bytes("caller must own given token"));
        ccAdmin.createOption(
            300000000000000000,
            100,
            300,
            2000000000000000000,
            2,
            address(nft)
        );
    }

    // check 4 ok creation => OK
    function testCreateOption() public {
        uint256 optID = createOption();
        assertEq(optID, 1);
    }

    // Test Buy Option
    // check 4 expired Option => OK
    function testBuyExpiredOption() public {
        createOption();
        vm.warp(220);
        vm.expectRevert(bytes("option already expired"));
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }

    // check 4 sold Option => OK
    function testBuySoldOption() public {
        createOption();
        vm.prank(optionBuyer);
        vm.warp(5);
        /*uint256 sE;
        (, , , , , , sE, , , ) = ccAdmin.options(1);
        emit log_uint(sE);
        emit log_uint(block.timestamp);
        */
        ccAdmin.buyOption{value: 300000000000000000}(1);
        vm.prank(optionBuyer2);
        vm.expectRevert(bytes("option already sold"));
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }

    // check 4 non existent Option => OK
    function testBuyNEOption() public {
        createOption();
        vm.prank(optionBuyer);
        vm.expectRevert(bytes("non existent option"));
        ccAdmin.buyOption{value: 300000000000000000}(14);
    }

    // check 4 msg value != premium
    function testBuyOpMsgValueNPremium() public {
        createOption();
        vm.prank(optionBuyer);
        vm.expectRevert(bytes("value != premium"));
        ccAdmin.buyOption{value: 3000000}(1);
    }

    // test an ok buy
    function testBuyOption()public{
        buyOption();
    }

    // test Exercise Option
    // test for wrong price
    function testExerciseOPInvalidPrice() public {
        buyOption();
        emit log("buy worked");
        vm.warp(250);
        uint256 stprice;
        vm.expectRevert(bytes("value != strike Price"));
        vm.prank(optionBuyer);
        ccAdmin.exerciseOption{value: 2000000000000}(1);
        assert(true);
    }

    // test for unauth user / not Owner
    function testExerciseOPInvalidUser() public {
        createOption();
        buyOption();
        vm.expectRevert(bytes("option must be owned"));
        vm.warp(150);
        // missing vm.prank(optionBuyer);
        ccAdmin.exerciseOption{value: 2000000000000000000}(1);
        assert(true);
    }

    // test 4 already executed Option
    function testExerciseOPAlreadyExecuted() public {
        createOption();
        buyOption();
        vm.expectRevert(bytes("option must be owned"));
        vm.warp(150);
        vm.prank(optionBuyer);
        ccAdmin.exerciseOption{value: 2000000000000000000}(1);
        assert(true);
    }

    // helper functions

    function buyOption() internal {
        vm.warp(100);
        createOption();
        vm.prank(optionBuyer);
        ccAdmin.buyOption{value: 300000000000000000}(1);
    }

    function createOption() internal returns(uint256 id){
        nft.mint(optionCreator, 1);
        vm.startPrank(optionCreator);
        nft.approve(address(ccAdmin), 1);
        id = ccAdmin.createOption(
            300000000000000000,
            100,
            300,
            2000000000000000000,
            1,
            address(nft)
        );
        emit log_uint(id);
        vm.stopPrank();
    }
}
