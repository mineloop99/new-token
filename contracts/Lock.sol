// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Prevents delegatecall to a contract
/// @notice Base contract that provides a modifier for preventing delegatecall to methods in a child contract
abstract contract NoDelegateCall {
    /// @dev The original address of this contract
    address private immutable original;

    constructor() {
        // Immutables are computed in the init code of the contract, and then inlined into the deployed bytecode.
        // In other words, this variable won't change when it's checked at runtime.
        original = address(this);
    }

    /// @dev Private method is used instead of inlining into modifier because modifiers are copied into each method,
    ///     and the use of immutable means the address bytes are copied in every place the modifier is used.
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice Prevents delegatecall into the modified method
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}

contract Locking is Ownable, ReentrancyGuard, NoDelegateCall {
    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // Info of each user.
    struct UserInfo {
        uint256 timeLastLocked; // Last time Staked to calculate apy
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 apy; // Rate of token per year apy/1000
        uint256 startTime;
        uint256 endTime;
    }

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
        uint256 _apy,
        uint256 _startTime
    ) {
        uint256 startTime = block.timestamp + _startTime;
        // staking pool
        poolInfo = PoolInfo({
            lpToken: _aniToken,
            apy: _apy,
            startTime: startTime,
            endTime: startTime + 31556926 // plus one year
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
    function enterStaking(uint256 _amount) public nonReentrant {
        require(poolInfo.endTime > getCurrentTime(), "Time: Farm has ended");
        require(
            poolInfo.lpToken.allowance(msg.sender, address(this)) >= _amount,
            "Allowance: Not enough Allowance"
        );
        UserInfo storage user = userInfo[msg.sender];
        if (_amount > 0) {
            poolInfo.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount + _amount;
        }
        user.timeLastStaked = block.timestamp;

        emit EnterStaking(msg.sender, _amount);
    }

    // Withdraw Ani tokens from STAKING.
    function leaveStaking(uint256 _amount) public whenNotPaused nonReentrant {
        PoolInfo storage pool = poolInfo;
        updateUser(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }
        emit LeaveStaking(msg.sender, _amount);
    }

    function updateUser(address _userAddress) public {
        if (getCurrentTime() >= poolInfo.endTime) {
            return;
        }
        UserInfo storage user = userInfo[_userAddress];
        user.rewardDebt += calculateRewardDebt(
            user.timeLastStaked,
            getCurrentTime(),
            user.amount
        );
    }

    // ClaimAllReward
    function claimReward() public whenNotPaused nonReentrant {
        updateUser(msg.sender);
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
        return (_userAmount * numberOfDays * apyPerDay) / (1000 * 1000);
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
