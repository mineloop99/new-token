// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract AniwarCollectible is ERC721URIStorage {
    struct AniwarItem {
        uint256 itemId;
        string name;
    }

    AniwarItem[] public aniwarItems;
    uint256 tokenCounter;
    event requestedAniwarItem(uint256 indexed requestId, address requester);

    constructor() ERC721("Aniwar", "ANI") {
        tokenCounter = 0;
    }

    function createAniwarItem(string memory _itemName) public {
        require(
            keccak256(abi.encodePacked((_itemName))) ==
                keccak256(abi.encodePacked((""))),
            "Please Specify the name of an Item"
        );
        uint256 itemId = tokenCounter;
        _safeMint(msg.sender, itemId);
        aniwarItems.push(AniwarItem(itemId, _itemName));
        tokenCounter = tokenCounter + 1;
        emit requestedAniwarItem(itemId, msg.sender);
    }

    function setTokenURI(uint256 itemId, string memory _tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), itemId),
            "ERC721: caller is not owner no app Approved"
        );
        _setTokenURI(itemId, _tokenURI);
    }

    function getAniwarItemOverView(uint256 itemId)
        public
        view
        returns (string memory, uint256)
    {
        return (aniwarItems[itemId].name, aniwarItems[itemId].itemId);
    }

    function getTokenURI(uint256 itemId) public view returns (string memory) {
        return tokenURI(itemId);
    }

    function _burn(uint256 itemId) internal override {
        super._burn(itemId);
    }
}
