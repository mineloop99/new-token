// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title TokenVesting 
 */
contract AniwarVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private immutable _token;

    struct VestingSchedule {
        // start time of the vesting period
        uint256 duration;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountReleased;
        //list Beneficiaries
        mapping(address => uint256) beneficiariesAmount;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    mapping(address => uint256) beneficiariesRate;

    uint256 private startedTime;
    uint256 private totalVestedAmount;
    uint256 private totalVestedAmountLeft;
    uint256 private totalVestedCount;
    // started when true
    bool private isStarted;
    mapping(uint256 => VestingSchedule) private vestingSchedules;
    event Released(uint256 amount);

    modifier onlyIfVestingScheduleStarted() {
        require(isStarted == true, "Vesting has not Started Yet!");
        _;
    }

    modifier onlyIfVestingScheduleNotStarted() {
        require(isStarted == false, "Vesting has Started!");
        _;
    }

    /*
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(address token_) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
    }


    function createVestingSchedule(uint256[] memory amounts, uint256 splitDuration)
    public 
    onlyOwner
    onlyIfVestingScheduleNotStarted
    {
        for (
            uint256 amountIndex = 0;
            amountIndex < amounts.length;
            amountIndex++
        ) 
        {
            VestingSchedule storage _temp = vestingSchedules[amountIndex];
            _temp.duration = amountIndex * splitDuration;
            _temp.amountReleased = amounts[amountIndex];
            _temp.revoked = false;
            totalVestedAmount = totalVestedAmount + amounts[amountIndex];
        }
        totalVestedCount = amounts.length;
        totalVestedAmountLeft = totalVestedAmount;
    }


    function startVestingSchedule()
    public 
    onlyOwner
    {
        isStarted = true;
    }


    function addBeneficiary(address _beneficiary, uint256 _vestingRate)
    public 
    onlyOwner
    {
        uint256 totalAmount = _calculateFullAmountByVestedRate(_vestingRate);
        require(
            _token.balanceOf(address(this)) - totalAmount >= 0,
            "Current contract amount insufficent!"
        );
        require(
            startedTime + vestingSchedules[totalVestedCount-1].duration > getCurrentTime(),
            "Current vesting has passed!"
        );
        require(
            totalVestedAmountLeft - totalAmount > 0,
            "Total amount left insufficents amount"
        );
        beneficiariesRate[_beneficiary] = _vestingRate;
        for (
            uint256 vestingScheduleIndex = 0;
            vestingScheduleIndex < totalVestedCount;
            vestingScheduleIndex++
        ) 
        {
            VestingSchedule storage _temp = vestingSchedules[vestingScheduleIndex];
            _temp.beneficiariesAmount[_beneficiary] = 
            _calculateSingleAmountByVestedRate(_vestingRate,vestingScheduleIndex);
        }
    }

    
    function releaseToken(uint256 _vestingScheduleIndex)
    public 
    nonReentrant
    onlyIfVestingScheduleStarted
    {
        uint256 currentAmount = vestingSchedules[_vestingScheduleIndex].beneficiariesAmount[address(msg.sender)];
        VestingSchedule storage _vestingSchedule = vestingSchedules[_vestingScheduleIndex];
        require(
            currentAmount > 0,
            "You are not beneficiary or current vested amount = 0 !"
        );
        require(
            _vestingSchedule.amountReleased > currentAmount,
            "current vested amount insufficent!"
        );
        require(
            startedTime + _vestingSchedule.duration > getCurrentTime(),
            "current vested amount insufficent!"
        );
        address payable beneficiaryPayable = payable(
            msg.sender
        );
        _vestingSchedule.amountReleased = _vestingSchedule.amountReleased - currentAmount;
        totalVestedAmount = totalVestedAmount - currentAmount;
        _token.safeTransfer(beneficiaryPayable, currentAmount);
        if (_vestingSchedule.amountReleased == 0) {
            _vestingSchedule.revoked = true;
        }
        emit Released(currentAmount);
    }

    function _calculateCurrentVestingScheduleIndex() 
    internal view returns(uint256) 
    {
        uint256 currentTime = getCurrentTime();
        for (
            uint256 vestingScheduleIndex = 0;
            vestingScheduleIndex < totalVestedCount;
            vestingScheduleIndex++
        ) 
        {
            if(currentTime < (startedTime + vestingSchedules[vestingScheduleIndex].duration)) {
                return vestingScheduleIndex;
            }
        }
        return totalVestedCount - 1;
    }

    function _calculateSingleAmountByVestedRate(uint256 _vestingRate, uint256 _vestingScheduleIndex) 
    internal view returns(uint256) 
    {
        return _vestingRate * vestingSchedules[_vestingScheduleIndex].amountReleased / 100;
    }


    function _calculateFullAmountByVestedRate(uint256 _vestingRate) 
    internal view returns(uint256) 
    {
        uint256 totalAmount = 0;
        for (
            uint256 vestingScheduleIndex = 0;
            vestingScheduleIndex < totalVestedCount;
            vestingScheduleIndex++
        ) 
        {
            totalAmount = totalAmount 
            + (_vestingRate 
            * vestingSchedules[vestingScheduleIndex].amountReleased)
            / 100;
        }
        return totalAmount;
    }


    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
