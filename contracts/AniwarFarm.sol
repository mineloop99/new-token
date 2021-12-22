// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract AniwarFarm is Ownable {
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenDataFeedMapping;
    address[] public stakers;
    address[] public allowedTokens;
    mapping(address => uint256) public stakingBnbBalance;
    IERC20 public token;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function setDataFeedContract(address _token, address _dataFeed)
        public
        onlyOwner
    {
        tokenDataFeedMapping[_token] = _dataFeed;
    }

    function issueTokens() public onlyOwner {
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            token.transfer(recipient, userTotalValue);
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
        if (uniqueTokensStaked[_staker] <= 0) {
            return 0;
        }
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return ((stakingBalance[_token][_staker] * price) / 10**decimals);
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        address dataFeedAddress = tokenDataFeedMapping[_token];
        AggregatorV3Interface dataFeed = AggregatorV3Interface(dataFeedAddress);
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 decimals = dataFeed.decimals();
        return (uint256(price), decimals);
    }

    function stakeTokens(uint256 _amount, address _token) public payable {
        require(_amount > 0, "amount must be more than 0!");
        require(tokenIsAllowed(_token), "Token is currently not allowed!");
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            "Token exceeds allowance!"
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function stakeBnb() public payable {
        require(msg.value > 0, "amount must be more than 0!");
        stakingBnbBalance[msg.sender] += msg.value;
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

    function updateUniqueTokensStaked(address _staker, address _token) private {
        if (stakingBalance[_token][_staker] <= 0) {
            uniqueTokensStaked[_staker] = uniqueTokensStaked[_staker] + 1;
        }
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function tokenIsAllowed(address _token) public view returns (bool) {
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
