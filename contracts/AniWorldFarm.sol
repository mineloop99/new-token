// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AniWorldFarm is Ownable {
    //Token address => Staker Address => amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenDataFeedMapping;
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public token;

    constructor(address _tokenAddress) public {
        token = IERC20(_tokenAddress);
    }

    function setDataFeedContract(address _token, address _dataFeed)
        public
        onlyOwner
    {
        tokenDataFeedMapping[_token] = _dataFeed;
    }

    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            token.transfer(recipient, userTotalValue);
            //dappToken.transfer(recipient, )
            // send them a token reward
            // based on their total value locked
        }
    }

    function getUserTotalValue(address _staker) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_staker] > 0, "No tokens staked!");
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(
                    _staker,
                    allowedTokens[allowedTokensIndex]
                );
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _staker, address _token)
        public
        view
        returns (uint256)
    {
        // 1 ETH -> 4500$
        if (uniqueTokensStaked[_staker] <= 0) {
            return 0;
        }
        // price of the token * stakingBalance[_token][user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return // 10 ETH
        // ETH/USD
        ((stakingBalance[_token][_staker] * price) / 10**decimals);
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        // dataFeedAddress
        address dataFeedAddress = tokenDataFeedMapping[_token];
        AggregatorV3Interface dataFeed = AggregatorV3Interface(dataFeedAddress);
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 decimals = dataFeed.decimals();
        return (uint256(price), decimals);
    }

    function stakeTokens(uint256 _amount, address _token) public {
        // Token address?
        // Amount?
        require(_amount > 0, "amount must be more than 0!");
        require(tokenIsAllowed(_token), "Token is currently not allowed!");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0!");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }

    function updateUniqueTokensStaked(address _staker, address _token)
        internal
    {
        if (stakingBalance[_token][_staker] <= 0) {
            uniqueTokensStaked[_staker] = uniqueTokensStaked[_staker] + 1;
        }
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }
}
