// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

contract Locking is
    ERC20("XOXO Clone", "gXOXO"),
    Ownable,
    ReentrancyGuard,
    NoDelegateCall
{
    using SafeERC20 for IERC20;

    IERC20 public immutable xoxo;
    // Info of each user.
    struct UserInfo {
        uint256 timeLastLocked; // Last time Staked to calculate apr
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 apr; // Rate of token per year apr/1000
        uint256 startTime;
        uint256 endTime;
    }

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    event EnterLocking(address indexed user, uint256 amount);
    event LeaveLocking(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _xoxo,
        uint256 _apr,
        uint256 _startTime
    ) {
        uint256 startTime = block.timestamp + _startTime;
        xoxo = _xoxo;
        // Locking pool
        poolInfo = PoolInfo({
            apr: _apr,
            startTime: startTime,
            endTime: startTime + 31556926 // plus one year
        });
    }

    // Update the given pool's Ani apr. Can only be called by the owner.
    function setApr(uint256 _apr) public onlyOwner {
        poolInfo.apr = _apr;
    }

    // Update the given pool's Ani apr. Can only be called by the owner.
    function setEndTime(uint256 _endTime) public onlyOwner {
        require(_endTime > getCurrentTime());
        poolInfo.endTime = _endTime;
    }

    // Lock tokens to Pool
    function enterLocking(uint256 _amount) public nonReentrant noDelegateCall {
        require(poolInfo.endTime > getCurrentTime(), "Time: Farm has ended");
        UserInfo storage user = userInfo[msg.sender];
        if (_amount > 0) {
            xoxo.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.timeLastLocked = block.timestamp;

        emit EnterLocking(msg.sender, _amount);
    }

    // Withdraw Ani tokens from Locking.
    function leaveLocking(uint256 _amount) public nonReentrant {
        updateUser(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            xoxo.safeTransfer(msg.sender, _amount);
        }
        emit LeaveLocking(msg.sender, _amount);
    }

    function updateUser(address _userAddress) public {
        if (getCurrentTime() >= poolInfo.endTime) {
            return;
        }
        UserInfo storage user = userInfo[_userAddress];
        user.rewardDebt += calculateRewardDebt(
            user.timeLastLocked,
            getCurrentTime(),
            user.amount
        );
    }

    // ClaimAllReward
    function claimReward() public nonReentrant noDelegateCall {
        updateUser(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        require(user.rewardDebt > 0, "Reward Amount: wut?");
        xoxo.safeTransfer(msg.sender, user.rewardDebt);
        emit ClaimReward(msg.sender, user.rewardDebt);
        user.rewardDebt = 0;
    }

    // Get time by current Time
    function calculateRewardDebt(
        uint256 _from,
        uint256 _to,
        uint256 _userAmount
    ) public view noDelegateCall returns (uint256) {
        uint256 time = _to - _from;
        uint256 numberOfDays = time / 86400; // 1 Day = 86400 seconds
        uint256 aprPerDay = (poolInfo.apr * 1000) / 365;
        return (_userAmount * numberOfDays * aprPerDay) / (1000 * 1000);
    }

    // Safe transfer function, just in case if rounding error causes pool to not have enough Tokens.
    function safeXoxoTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 xoxoBal = xoxo.balanceOf(address(this));
        if (_amount > xoxoBal) {
            xoxo.transfer(_to, xoxoBal);
        } else {
            xoxo.transfer(_to, _amount);
        }
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    // returns how much XOXO someone gets for redeeming gXOXO
    function gXOXOForXOXO(uint256 _gXOXOAmount)
        external
        view
        noDelegateCall
        returns (uint256 xoxoAmount_)
    {
        uint256 totalgXOXO = totalSupply();
        xoxoAmount_ =
            (_gXOXOAmount * xoxo.balanceOf(address(this))) /
            totalgXOXO;
    }

    // returns how much gXOXO someone gets for depositing XOXO
    function XoxoForgXoxo(uint256 _xoxoAmount)
        external
        view
        returns (uint256 gXoxoAmount_)
    {
        uint256 totalXoxo = xoxo.balanceOf(address(this));
        uint256 totalgXoxo = totalSupply();
        if (totalgXoxo == 0 || totalXoxo == 0) {
            gXoxoAmount_ = _xoxoAmount;
        } else {
            gXoxoAmount_ = (_xoxoAmount * totalgXoxo) / totalXoxo;
        }
    }
}
