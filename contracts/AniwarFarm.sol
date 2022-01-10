// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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

contract AniwarFarm is Ownable, Pausable, ReentrancyGuard {
    struct StakerInfo {
        uint256 timeLastStaked; // Last time Staked to calculate apy
        uint256 stakingBnbBalance; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        // stakingBalance[TokenAddress]
        mapping(address => uint256) stakingBalance;
    }
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenDataFeedMapping;
    address[] public stakers;
    address[] public allowedTokens;
    mapping(address => StakerInfo) public stakersInfo;

    uint256 public aniToUsdDataFeed; // DataFeed ANI/USD
    address public constant bnbDataFeed =
        0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
    uint256 public apy; // APY/1000 per year
    IERC20 public token;

    constructor(address _tokenAddress, uint256 _apy) {
        token = IERC20(_tokenAddress);
        apy = _apy;
    }

    function setDataFeedContract(address _token, address _dataFeed)
        public
        onlyOwner
    {
        tokenDataFeedMapping[_token] = _dataFeed;
    }

    function issueTokens() public onlyOwner nonReentrant {
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = calculateRewardDebt(
                recipient,
                stakersInfo[recipient].timeLastStaked,
                getCurrentTime()
            );
            token.transfer(recipient, userTotalValue);
        }
    }

    function stakeTokens(uint256 _amount, address _token)
        public
        nonReentrant
        whenNotPaused
    {
        require(_amount > 0, "amount must be more than 0!");
        require(tokenIsAllowed(_token), "Token is currently not allowed!");
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            "Token exceeds allowance!"
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        StakerInfo storage stakerInfo = stakersInfo[msg.sender];
        stakerInfo.stakingBalance[_token] =
            stakerInfo.stakingBalance[_token] +
            _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
        uint256 currentTime = getCurrentTime();
        stakerInfo.rewardDebt += calculateRewardDebt(
            msg.sender,
            stakerInfo.timeLastStaked,
            currentTime
        );
        stakerInfo.timeLastStaked = currentTime;
    }

    function stakeBnb() public payable nonReentrant whenNotPaused {
        require(msg.value > 0, "amount must be more than 0!");
        StakerInfo storage stakerInfo = stakersInfo[msg.sender];
        if (stakerInfo.stakingBnbBalance == 0) {
            uniqueTokensStaked[msg.sender] += 1;
        }
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
        stakerInfo.stakingBnbBalance += msg.value;
        uint256 currentTime = getCurrentTime();
        stakerInfo.rewardDebt += calculateRewardDebt(
            msg.sender,
            stakerInfo.timeLastStaked,
            currentTime
        );
        stakerInfo.timeLastStaked = currentTime;
    }

    function unstakeBnb(uint256 _amount) public nonReentrant whenNotPaused {
        StakerInfo storage stakerInfo = stakersInfo[msg.sender];
        require(
            _amount <= stakerInfo.stakingBnbBalance,
            "amount must be more than 0!"
        );
        address payable senderPayable = payable(msg.sender);
        senderPayable.transfer(_amount);
        stakerInfo.stakingBnbBalance -= _amount;
        if (stakerInfo.stakingBnbBalance == 0) {
            uniqueTokensStaked[msg.sender] -= 1;
        }
        uint256 currentTime = getCurrentTime();
        stakerInfo.rewardDebt += calculateRewardDebt(
            msg.sender,
            stakerInfo.timeLastStaked,
            currentTime
        );
        stakerInfo.timeLastStaked = currentTime;
    }

    function unstakeTokens(address _token, uint256 _amount)
        public
        nonReentrant
        whenNotPaused
    {
        uint256 balance = stakersInfo[msg.sender].stakingBalance[_token];
        require(balance > 0, "Staking balance cannot be 0!");
        IERC20(_token).transfer(msg.sender, balance);
        StakerInfo storage stakerInfo = stakersInfo[msg.sender];
        stakerInfo.stakingBalance[_token] -= _amount;
        if (stakerInfo.stakingBalance[_token] == 0) {
            uniqueTokensStaked[msg.sender] -= 1;
        }
        uint256 currentTime = getCurrentTime();
        stakerInfo.rewardDebt += calculateRewardDebt(
            msg.sender,
            stakerInfo.timeLastStaked,
            currentTime
        );
        stakerInfo.timeLastStaked = currentTime;
    }

    function updateUniqueTokensStaked(address _staker, address _token) private {
        if (stakersInfo[msg.sender].stakingBalance[_token] == 0) {
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

    // Update the given pool's Ani Apy. Can only be called by the owner.
    function setApy(uint256 _apy) public onlyOwner {
        apy = _apy;
    }

    //Data feed rate amount = USD/(ANI*100)
    function setAniToUsdDataFeed(uint256 _amount) public onlyOwner {
        aniToUsdDataFeed = _amount;
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function getUserTotalValue(address _staker) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_staker] > 0, "No tokens staked!");
        if (allowedTokens.length > 0) {
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
        }
        (uint256 price, uint256 decimals) = getBnbValue();
        totalValue += ((stakersInfo[_staker].stakingBnbBalance * price) /
            10**decimals);
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
        return ((stakersInfo[_staker].stakingBalance[_token] * price) /
            10**decimals);
    }

    function getBnbValue() public view returns (uint256, uint256) {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(bnbDataFeed);
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 decimals = dataFeed.decimals();
        return (uint256(price), decimals);
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

    function calculateRewardDebt(
        address _stakerAddr,
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        uint256 balanceInUsd = getUserTotalValue(_stakerAddr);
        if (balanceInUsd == 0) {
            return 0;
        }
        uint256 _userAmount = aniToUsdDataFeed * balanceInUsd;
        uint256 multiplier = _to - _from;
        uint256 numberOfDays = multiplier / 86400; // 1 Day = 86400 seconds
        uint256 apyPerDay = (apy * 1000) / 365;
        return (_userAmount * numberOfDays * apyPerDay) / (1000 * 1000 * 100);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
