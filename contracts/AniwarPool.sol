// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AniwarPool is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // Info of each user.
    struct UserInfo {
        uint256 timeLastStaked; // Last time Staked to calculate apy
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 apy; // Rate of token per year apy/100
        uint256 startTime;
        uint256 endTime;
    }

    // recipient address.
    address public recipient;
    // Bonus muliplier for early ani makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    event EnterStaking(address indexed user, uint256 amount);
    event LeaveStaking(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _aniToken,
        address _recipient,
        uint256 _apy,
        uint256 _startTime
    ) {
        recipient = _recipient;

        // staking pool
        poolInfo = PoolInfo({
            lpToken: _aniToken,
            apy: _apy,
            startTime: block.timestamp + _startTime,
            endTime: 0
        });
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Update the given pool's Ani Apy. Can only be called by the owner.
    function setApy(uint256 _apy) public onlyOwner {
        poolInfo.apy = _apy;
    }

    // Update the given pool's Ani Apy. Can only be called by the owner.
    function setEndTime(uint256 _endTime) public onlyOwner {
        require(_endTime > getCurrentTime());
        poolInfo.endTime = _endTime;
    }

    // Stake Ani tokens to AniPool
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount + _amount;
        }
        user.timeLastStaked = block.timestamp;
        user.rewardDebt += calculateRewardDebt(
            user.timeLastStaked,
            getCurrentTime(),
            user.amount
        );

        emit EnterStaking(msg.sender, _amount);
    }

    // Withdraw Ani tokens from STAKING.
    function leaveStaking(uint256 _amount) public whenNotPaused {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }
        user.timeLastStaked = block.timestamp;
        user.rewardDebt += calculateRewardDebt(
            user.timeLastStaked,
            getCurrentTime(),
            user.amount
        );

        emit LeaveStaking(msg.sender, _amount);
    }

    // ClaimAllReward
    function claimReward() public whenNotPaused nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.rewardDebt > 0, "Reward Amount: wut?");
        poolInfo.lpToken.safeTransfer(msg.sender, user.rewardDebt);
        emit ClaimReward(msg.sender, user.rewardDebt);
        user.rewardDebt = 0;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        poolInfo.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Get time by current Time
    function calculateRewardDebt(
        uint256 _from,
        uint256 _to,
        uint256 _userAmount
    ) public view returns (uint256) {
        uint256 multiplier = (_to - _from) * BONUS_MULTIPLIER;
        uint256 numberOfDays = multiplier / 86400; // 1 Day = 86400 seconds
        uint256 apyPerDay = (poolInfo.apy * 1000) / 365;
        return _userAmount * (numberOfDays / 1000) * (apyPerDay / 100);
    }

    // Update recipient address by the previous dev.
    function changeRecipient(address _recipient) public {
        require(msg.sender == recipient, "dev: wut?");
        recipient = _recipient;
    }

    // Safe ani transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safeAniTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 aniBal = poolInfo.lpToken.balanceOf(address(this));
        if (_amount > aniBal) {
            poolInfo.lpToken.transfer(_to, aniBal);
        } else {
            poolInfo.lpToken.transfer(_to, _amount);
        }
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
