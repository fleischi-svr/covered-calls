// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// MIN duration: hardEnd - softEnd => through Governance

contract CCAdmin is Ownable {

    modifier validOption(uint256 optID) {
        require(!options[optID].sold, "option already sold");
        require(block.timestamp < (options[optID].softEnd),
        "option already expired");
        _;
    }

    modifier optionOwner(uint256 optID) {
        require(msg.sender == optionBuyer[optID], "option must be owned");
        _;
    }

    modifier executable(uint256 optID) {
        require(!options[optID].executed);
        require(
            block.timestamp > options[optID].softEnd &&
                block.timestamp < options[optID].hardEnd
        );
        _;
    }
    modifier onlyCreator(uint256 optID) {
        require(options[optID].creator == msg.sender,
        "Caller must be the Creator of the Option");
        _;
    }

    modifier onlyNFTOwner(address nftAddress, uint256 identifier) {
        ERC721 token = ERC721(nftAddress);
        require(
            token.ownerOf(identifier)==msg.sender,
            "caller must own given token"
        );
        _;
    }

    modifier expiredOption(uint256 optID){
        require(block.timestamp > options[optID].hardEnd);
        _;
    }

    uint256 private counter;

    constructor() {
        counter = 0;
    }

    struct Option {
        // Struct names upper case
        uint256 optionID;
        address creator;
        address nftAddress;
        uint256 nftIdentifier;
        uint256 premium;
        uint256 strikePrice;
        uint256 softEnd;
        uint256 hardEnd;
        bool sold;
        bool executed;
    }

    mapping(uint256 => Option) public options;
    // optID => Owner of Option address
    mapping(uint256 => address) public optionBuyer;

    function createOption(
        uint256 premium,
        uint256 softEnd, // sekunden
        uint256 hardEnd, // sekunden
        uint256 price,
        uint256 nftIdentifier,
        address nftAddress
    ) public onlyNFTOwner(nftAddress, nftIdentifier) returns (uint256 optionID) {
        //check with modifiers
        //effects counter & so
        uint256 optID = counter;
        ++counter; // is gas effizienter wie counter++
        // Take time now + the duration he wants to lock it (3 weeks)
        uint256 softE = block.timestamp + softEnd;
        uint256 hardE = block.timestamp + hardEnd;
        Option memory op = Option(
            optID,
            msg.sender,
            nftAddress,
            nftIdentifier,
            premium,
            price,
            softE,
            hardE,
            false,
            false
        );
        // effects
        options[optID] = op;
        // T ODO EVENT
        return optID;
    }

    function buyOption(uint256 optID) public payable validOption(optID) {
        //check
        require(msg.value == options[optID].premium);
        //effect
        options[optID].sold = true;
        //interaction
        optionBuyer[optID] = msg.sender;
        (bool success, ) = options[optID].creator.call{value: msg.value}("");
        require(success);
        //timelock
    }

    function exerciseOption(uint256 optID)
        public
        payable
        optionOwner(optID)
        executable(optID)
    {
        // check if option is owned => modifier optionOwner
        require(msg.value == options[optID].strikePrice, "value != premium");

        // check if blockTimestamp > _timestamp  => modifier executable
        // complete option
        options[optID].executed = true;
        // execute TX

        // Er zoit strike price
        (bool success, ) = options[optID].creator.call{value: msg.value}("");
        require(success);

        // Er griagt NFT
        ERC721 nft = ERC721(options[optID].nftAddress);
        
        nft.transferFrom(
            address(this),
            optionBuyer[optID],
            options[optID].nftIdentifier
        );
    }

    function revokeOptionVCreator(uint256 optID)public onlyCreator(optID) {
        require(!options[optID].sold);
        options[optID].sold = true;
        options[optID].executed = true;
        // Retrieve NFT from Contract to original Owner
        ERC721 nft = ERC721(options[optID].nftAddress);
        nft.transferFrom(
            address(this),
            options[optID].creator,
            options[optID].nftIdentifier
        );
    }

    function revokeOptionVAll(uint256 optID)public  expiredOption(optID){
        options[optID].sold = true;
        options[optID].executed = true;
        // Retrieve NFT from Contract to original Owner
        ERC721 nft = ERC721(options[optID].nftAddress);
        nft.transferFrom(
            address(this),
            options[optID].creator,
            options[optID].nftIdentifier
        );
    }
}
