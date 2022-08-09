// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract AniwarNft is ERC721Enumerable, Ownable {
    IERC20 public immutable ANIWAR_ERC20_TOKEN;
    uint256 public mintFee = 200; // Aniwar nft mint fee: mintFee * 10 ** decimals
    struct AniwarItem {
        uint256 itemId;
        string name;
    }

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    AniwarItem[] public aniwarItems;
    uint256 tokenCounter;
    event requestedAniwarItem(uint256 indexed requestId, address requester);

    constructor(address _ani_erc20_token) ERC721("Aniwar", "ANI") {
        tokenCounter = 0;
        ANIWAR_ERC20_TOKEN = IERC20(_ani_erc20_token);
    }

    function setMintFee(uint256 _fee) public onlyOwner {
        mintFee = _fee;
    }

    function createAniwarItem(string memory _itemName) private {
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

    function createManyAniwarItem(uint8 _count, string[] memory names) public {
        uint256 _totalFee = _count *
            mintFee *
            10**ANIWAR_ERC20_TOKEN.decimals();
        require(_count <= 10, "Number max is 10");
        require(
            ANIWAR_ERC20_TOKEN.balanceOf(msg.sender) >= _totalFee,
            "insufficient balance"
        );
        for (uint8 i = 0; i < _count; i++) {
            createAniwarItem(names[i]);
        }
        ANIWAR_ERC20_TOKEN.transferFrom(msg.sender, address(this), _totalFee);
    }

    function setTokenURI(uint256 itemId, string memory _tokenURI)
        public
        onlyOwner
    {
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
