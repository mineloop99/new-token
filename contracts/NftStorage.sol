// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftStorage is Ownable {
    IERC721 private immutable _tokenContract;
    struct Token {
        bool isInit;
        uint256 tokenId;
    }
    mapping(uint256 => address) public _nftDepositor;
    mapping(uint256 => Token) public _nft;
    uint256 private _tokenIndexCount = 0;

    constructor(address tokenContract_) {
        _tokenContract = IERC721(tokenContract_);
    }

    function deposit(uint256 _tokenId) public {
        require(
            _tokenContract.getApproved(_tokenId) == address(this),
            "Not Approved"
        );
        _tokenContract.transferFrom(msg.sender, address(this), _tokenId);
        _nftDepositor[_tokenId] = msg.sender;
        _nft[_tokenId] = Token({isInit: true, tokenId: _tokenId});
        _tokenIndexCount++;
    }

    function withdraw(uint256 _tokenIndex, address _withdrawer)
        public
        onlyOwner
    {
        _tokenContract.transferFrom(address(this), _withdrawer, _tokenIndex);
        _nft[_tokenIndex].tokenId = _tokenIndexCount;
        _tokenIndexCount--;
    }
}
