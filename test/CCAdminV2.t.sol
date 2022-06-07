// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./TestERC721.sol";
import "../src/CCAdminV2.sol";

contract CCAdminV2Test is Test {
    CCAdminV2 public ccAdminV2;
    TestERC721 public nft;

    address public optionCreator;
    address public randomDude;
    address public optionBuyer;
    address public optionBuyer2;

    function setUp() public {
        ccAdminV2 = new CCAdminV2();
        nft = new TestERC721();

        optionCreator = address(5);
        optionBuyer = address(6);
        optionBuyer2 = address(7);
        randomDude = address(10);

        vm.deal(optionCreator, 3 ether);
        vm.deal(optionBuyer, 3 ether);
        vm.deal(optionBuyer2, 3 ether);
        vm.deal(randomDude, 3 ether);
    }

    // Test Create Option ---------------------------------------------------------

    // check 4 not owned NFT => OK
    function testFailOptionTokenNOwned() public {
        mintNft(randomDude, 1);
        //createOption(nftAddress, nftID, premium, strikePrice, epStart, epEnd);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
    }

    // Check 4 existing ID not neccesary bc you cant create the same without the nft you dont have
    /*function testCreateOptionAlreadyExists() public {
        mintNft(optionCreator, 1);
        createOption(address(nft), 1, 20000000, 2000000000, 100, 300, optionCreator);
        vm.expectRevert(CCAdminV2.OptionAlreadyExists.selector);
        createOption(address(nft), 1, 20000000, 2000000000, 100, 300, optionCreator);
    }*/

    // check 4 ok creation => OK
    function testCreateOption() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
    }

    // Test Buy Option ---------------------------------------------------------

    // check 4 expired Option => OK
    function testBuyWindowClosed() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.OptionBuyExpired.selector,
                220,
                100
            )
        );
        //buyOption(warpTime, valueMsg, creator, nftAddress, nftID, premium, strikePrice, epStart, epEnd, opCreator);
        buyOption(
            220,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            200,
            optionBuyer
        );
    }

    // check 4 sold Option => OK
    function testBuyWrongPremium() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.WrongAmountPremium.selector,
                20000000,
                200
            )
        );
        buyOption(
            50,
            200,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            200,
            optionBuyer
        );
    }

    // check 4 non existent Option => OK
    function testBuyNEOption() public {
        // missing : createOption(address(nft), 1, 20000000, 2000000000, 100, 300, optionCreator);
        vm.expectRevert(CCAdminV2.NonExistentOption.selector);
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            200,
            optionBuyer
        );
    }

    // test an ok buy => OK
    function testBuyOption() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );
    }

    // test Exercise Option ---------------------------------------------------------

    // test for unauth user / not Owner => OK
    function testExerciseOPInvalidUser() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.NotOwnerError.selector,
                optionBuyer,
                optionBuyer2
            )
        );

        exerciseOption(
            150,
            20000000,
            optionBuyer,
            optionCreator,
            optionBuyer,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    // test for wrong price => OK
    function testExerciseOPWrongPrice() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.WrongAmountStrikePrice.selector,
                2000000000,
                2
            )
        );

        exerciseOption(
            150,
            2,
            optionBuyer,
            optionCreator,
            optionBuyer,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    // test for expired option => OK
    function testExerciseOPExpired() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.NotInExecutionTimeframe.selector,
                100,
                300,
                400 //30 works too
            )
        );

        exerciseOption(
            400,
            2000000000,
            optionBuyer,
            optionCreator,
            optionBuyer,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    // test for non existent option => OK
    function testExerciseOPNonExistent() public {
        mintNft(optionCreator, 1);
        /* missing:
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );*/

        vm.expectRevert(CCAdminV2.NonExistentOption.selector);

        exerciseOption(
            150,
            2000000000,
            optionBuyer,
            optionCreator,
            optionBuyer,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    // test exercise => OK
    function testExerciseOption() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        buyOption(
            50,
            20000000,
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionBuyer
        );

        exerciseOption(
            150,
            2000000000,
            optionBuyer,
            optionCreator,
            optionBuyer,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    //test revoke Option Creator ------------------------------------------

    // test user NOT Creator => OK
    function testRevokeOPNCreator() public {
        mintNft(optionCreator, 1);
        createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );
        vm.prank(randomDude);
        vm.expectRevert(
            abi.encodeWithSelector(
                CCAdminV2.SenderNotCreator.selector,
                optionCreator,
                randomDude
            )
        );
        ccAdminV2.revokeOptionVCreator(
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    // test option not existent => cannot send
    function testRevokeOPNExistent() public {
        mintNft(optionCreator, 1);
        /*createOption(
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300,
            optionCreator
        );*/
        vm.prank(optionCreator);
        vm.expectRevert(CCAdminV2.NonExistentOption.selector);
        ccAdminV2.revokeOptionVCreator(
            optionCreator,
            address(nft),
            1,
            20000000,
            2000000000,
            100,
            300
        );
    }

    
    // test revoke Option ALL Not expired => already sold => OK
    function testRevokeOPNExpiredAll() public {
        buyOption();
        vm.warp(100);
        vm.prank(optionCreator);
        vm.expectRevert("Option has not expired");
        ccAdmin.revokeOptionVAll(1);
    }
*/
    // helper functions
    function exerciseOption(
        uint256 warpTime,
        uint256 valueMsg,
        address opExerciser,
        address creator,
        address buyer,
        address nftAddress,
        uint256 nftID,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd
    ) internal {
        vm.warp(warpTime);
        vm.prank(opExerciser);
        ccAdminV2.exerciseOption{value: valueMsg}(
            creator,
            buyer,
            nftAddress,
            nftID,
            premium,
            strikePrice,
            epStart,
            epEnd
        );
    }

    function buyOption(
        uint256 warpTime,
        uint256 valueMsg,
        address creator,
        address nftAddress,
        uint256 nftID,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd,
        address opBuyer
    ) internal {
        vm.warp(warpTime);
        vm.prank(opBuyer);
        ccAdminV2.buyOption{value: valueMsg}(
            creator,
            nftAddress,
            nftID,
            premium,
            strikePrice,
            epStart,
            epEnd
        );
    }

    function createOption(
        address nftAddress,
        uint256 nftID,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd,
        address opCreator
    ) internal {
        vm.startPrank(opCreator);
        nft.approve(address(ccAdminV2), 1);
        ccAdminV2.createOption(
            nftAddress,
            nftID,
            premium,
            strikePrice,
            epStart,
            epEnd
        );
        emit log("Option Created");
        vm.stopPrank();
    }

    function mintNft(address sender, uint256 id) public {
        nft.mint(sender, id);
    }
}
