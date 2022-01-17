// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AniwarNft is ERC721Enumerable {
    struct AniwarItem {
        uint256 itemId;
        string name;
    }

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    AniwarItem[] public aniwarItems;
    uint256 tokenCounter;
    event requestedAniwarItem(uint256 indexed requestId, address requester);

    constructor() ERC721("Aniwar", "ANI") {
        tokenCounter = 0;
    }

    function createAniwarItem(string memory _itemName) public {
        require(
            keccak256(abi.encodePacked((_itemName))) !=
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

    function getTokenURI(uint256 itemId) public view returns (string memory) {
        return tokenURI(itemId);
    }   

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}
