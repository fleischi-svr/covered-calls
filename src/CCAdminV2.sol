// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

//import "forge-std/Test.sol";

// MIN duration: hardEnd - softEnd => through Governance

contract CCAdminV2 is Ownable {
    // Lookup info + Constructor
    mapping(bytes32 => bool) public optionExists;

    // Errors
    error NotOwnerError(address owner, address sender);
    error NonExistentOption();
    error OptionAlreadySold();
    error OptionBuyExpired(uint256 bockTimestamp, uint256 epStart);
    error NotInExecutionTimeframe(
        uint256 epStart,
        uint256 epEnd,
        uint256 blockTimestamp
    );
    error SenderNotCreator(address creator, address sender); // Überlegen kann ma des so checken bro,
    error NotNFTOwner();
    error OptionExpired(uint256 epEnd, uint256 blockTimestamp);
    error OptionAlreadyExists();
    error WrongAmountPremium(uint256 premium, uint256 msgValue);
    error WrongAmountStrikePrice(uint256 strikeP, uint256 msgValue);
    error CallFailed();

    // Modifier
    modifier buyWindowOpen(uint256 epStart) {
        if (block.timestamp > epStart) {
            revert OptionBuyExpired(block.timestamp, epStart);
        }
        _;
    }

    modifier optionOwner(address buyer) {
        if (msg.sender != buyer) {
            revert NotOwnerError(buyer, msg.sender);
        }
        _;
    }

    modifier onlyCreator(address creator) {
        if (msg.sender != creator) {
            revert SenderNotCreator(creator, msg.sender);
        }
        _;
    }

    modifier expiredOption(uint256 epEnd) {
        if (block.timestamp < epEnd) {
            revert OptionExpired(epEnd, block.timestamp);
        }
        _;
    }

    // Helper
    function generateOptionID(
        address creator,
        address buyer,
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd,
        bool bought,
        bool executed
    ) public pure returns (bytes32 opID) {
        return
            keccak256(
                abi.encode(
                    creator,
                    buyer,
                    nftAddress,
                    nftIdentifier,
                    premium,
                    strikePrice,
                    epStart,
                    epEnd,
                    bought,
                    executed
                )
            );
    }

    // Functions
    function createOption(
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart, // sekunden
        uint256 epEnd // sekunden
    ) public {
        //check + modifiers check
        bytes32 opID = generateOptionID(
            msg.sender,
            0x0000000000000000000000000000000000000000,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            false,
            false
        );

        // check if there is already such an option
        if (optionExists[opID]) {
            revert OptionAlreadyExists();
        }
        // set the mapping
        optionExists[opID] = true;

        // Send NFT from Creator => Contract
        ERC721 nft = ERC721(nftAddress);
        nft.transferFrom(msg.sender, address(this), nftIdentifier);
    }

    function buyOption(
        address creator,
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd
    ) public payable buyWindowOpen(epStart) {
        if (msg.value != premium) {
            revert WrongAmountPremium(premium, msg.value);
        }
        //check gibts jo daun nur 1x weil waun es den mit 1x true ba verkauft gibt => is jo der nimma existent es started immer mit false false => true false ..
        bytes32 opID = generateOptionID(
            creator,
            0x0000000000000000000000000000000000000000,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            false,
            false
        );

        // check if there is already such an option
        if (optionExists[opID]) {
            revert OptionAlreadyExists();
        }

        //effect
        // make new ID => delete old id => insert new one
        bytes32 opIDNew = generateOptionID(
            creator,
            0x0000000000000000000000000000000000000000,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            true,
            false
        );
        delete optionExists[opID];
        optionExists[opIDNew] = true;

        //interaction => send premium to option creator
        (bool success, ) = creator.call{value: msg.value}("");
        if (!success) {
            revert CallFailed();
        }
    }

    function exerciseOption(
        address creator,
        address buyer,
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd
    ) public payable optionOwner(buyer) {
        // check if option is owned => modifier optionOwner
        if (msg.value != strikePrice) {
            revert WrongAmountStrikePrice(strikePrice, msg.value);
        }

        if (block.timestamp < epStart || block.timestamp > epEnd) {
            revert NotInExecutionTimeframe(epStart, epEnd, block.timestamp);
        }

        // check if option exists
        bytes32 opID = generateOptionID(
            creator,
            buyer,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            true,
            false
        );

        if (!optionExists[opID]) {
            revert NonExistentOption();
        }

        // delete Option with option ID = opID => dont need this or new one bc you not gonna save it anyways
        delete optionExists[opID];

        // Caller pays strike price to option creator
        (bool success, ) = creator.call{value: msg.value}("");

        if (success) {
            revert CallFailed();
        }

        // caller gets the NFT
        ERC721 nft = ERC721(nftAddress);

        nft.transferFrom(address(this), buyer, nftIdentifier);
    }

    function revokeOptionVCreator(
        address creator,
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd
    ) public onlyCreator(creator) {
        bytes32 opID = generateOptionID(
            creator,
            0x0000000000000000000000000000000000000000,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            false,
            false
        );
        // if != option already sold or not existent at all != cannot revoke
        if (optionExists[opID]) {
            revert NonExistentOption();
        }

        delete optionExists[opID];

        // Retrieve NFT from Contract to original Owner
        ERC721 nft = ERC721(nftAddress);
        nft.transferFrom(address(this), creator, nftIdentifier);
    }

    function revokeOptionVAll(
        address creator,
        address nftAddress,
        uint256 nftIdentifier,
        uint256 premium,
        uint256 strikePrice,
        uint256 epStart,
        uint256 epEnd
    ) public expiredOption(epEnd) {
        bytes32 opID = generateOptionID(
            creator,
            0x0000000000000000000000000000000000000000,
            nftAddress,
            nftIdentifier,
            premium,
            strikePrice,
            epStart,
            epEnd,
            false,
            false
        );
        // if != option already sold or not existent at all != cannot revoke
        if (optionExists[opID]) {
            revert NonExistentOption();
        }
        delete optionExists[opID];
        // Retrieve NFT from Contract to original Owner
        ERC721 nft = ERC721(nftAddress);
        nft.transferFrom(address(this), creator, nftIdentifier);
    }
}
