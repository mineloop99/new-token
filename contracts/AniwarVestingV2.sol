// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVesting
 */
contract AniwarVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // address of the ERC20 token
    IERC20 private immutable _token;

    struct Beneficiary {
        uint256 totalAmount;
        uint256 TGEAmount;
        uint256 cliff;
        uint256 totalAmountHasBeenWithdrawn;
        bool isInitialized;
    }

    bool private _isStarted;
    uint256 private _startedTime;
    uint256 private immutable _splitDuration;
    uint256 private immutable _splitCount;
    uint256 private _vestingSchedulesInitializedAmount;
    uint256 private _vestingSchedulesInitializedAmountLeft;

    address[] private _beneficiariesAddress;
    mapping(address => Beneficiary) public beneficiaries;

    event Released(uint256 amount);
    event Begin();

    modifier onlyIfVestingScheduleStarted() {
        require(_isStarted, "Vesting is not Started Yet!");
        _;
    }
    modifier onlyIfVestingScheduleNotStarted() {
        require(!_isStarted, "Vesting is Started!");
        _;
    }

    constructor(
        address token_,
        uint256 splitDuration_,
        uint256 splitCount_,
        uint256 initializedAmount_
    ) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
        _splitDuration = splitDuration_;
        require(splitCount_ > 0, "Split counter must be > 0");
        _splitCount = splitCount_;
        _vestingSchedulesInitializedAmount = initializedAmount_;
        _vestingSchedulesInitializedAmountLeft = initializedAmount_;
    }

    // _TGERatio is a First release when schedule started: _TGERatio = %
    function addBeneficiary(
        address _beneficiary,
        uint256 _cliff,
        uint256 _amount,
        uint256 _TGERatio
    ) public onlyOwner onlyIfVestingScheduleNotStarted {
        require(
            _amount <= _vestingSchedulesInitializedAmountLeft,
            "TokenVesting: cannot add beneficiary  because not sufficient tokens"
        );
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(_cliff < _splitCount, "cliff must less than sum of split");
        require(_TGERatio < 100, "Rate must less than 100%");
        Beneficiary storage beneficiary = beneficiaries[_beneficiary];
        if (!beneficiary.isInitialized) {
            beneficiary.isInitialized = true;
            _beneficiariesAddress.push(_beneficiary);
        }
        beneficiary.cliff = _cliff;
        beneficiary.totalAmount += _amount;
        beneficiary.TGEAmount += (_amount * _TGERatio) / 100;
        _vestingSchedulesInitializedAmountLeft -= _amount;
    }

    function startSchedule(uint256 _time)
        public
        onlyOwner
        onlyIfVestingScheduleNotStarted
    {
        require(
            _token.balanceOf(address(this)) >=
                _vestingSchedulesInitializedAmount,
            "Amount exceeds balance and Init"
        );
        _isStarted = true;
        _startedTime = _time;
        emit Begin();
    }

    function releaseAll()
        public
        onlyOwner
        onlyIfVestingScheduleStarted
        nonReentrant
    {
        for (
            uint256 beneficiaryIndex = 0;
            beneficiaryIndex < _beneficiariesAddress.length;
            beneficiaryIndex++
        ) {
            address beneficiaryAddress = _beneficiariesAddress[
                beneficiaryIndex
            ];
            Beneficiary storage beneficiary = beneficiaries[beneficiaryAddress];
            uint256 amount = calculateWithdrawableAmount(beneficiaryAddress);
            if (beneficiary.isInitialized && amount > 0) {
                beneficiary.totalAmountHasBeenWithdrawn += amount;
                address payable beneficiaryPayable = payable(
                    beneficiaryAddress
                );
                _token.safeTransfer(beneficiaryPayable, amount);
                emit Released(amount);
            }
        }
    }

    function releaseOne() public onlyIfVestingScheduleStarted nonReentrant {
        address senderAddress = msg.sender;
        uint256 amount = calculateWithdrawableAmount(senderAddress);
        Beneficiary storage beneficiary = beneficiaries[senderAddress];
        require(
            beneficiary.isInitialized,
            "TokenVesting: only beneficiary can release vested tokens"
        );
        require(amount > 0, "Amount can be Released must be > 0");
        address payable beneficiaryPayable = payable(senderAddress);
        _token.safeTransfer(beneficiaryPayable, amount);
        emit Released(amount);
    }

    function calculateWithdrawableAmount(address _beneficiary)
        public
        view
        onlyIfVestingScheduleStarted
        returns (uint256)
    {
        Beneficiary memory beneficiary = beneficiaries[_beneficiary];
        uint256 currentTime = getCurrentTime();
        if (!beneficiary.isInitialized || currentTime < _startedTime) {
            return 0;
        }
        uint256 currentSplit = (currentTime - _startedTime) / _splitDuration;
        if (currentSplit >= _splitCount) {
            currentSplit = _splitCount;
        }
        if (currentSplit == 0) {
            currentSplit = 1;
        }
        if (currentSplit < beneficiary.cliff) {
            return 0;
        }
        uint256 singleSplitAmount = (beneficiary.totalAmount -
            beneficiary.TGEAmount) / (_splitCount - 1 - beneficiary.cliff);
        return
            singleSplitAmount *
            (currentSplit - 1 - beneficiary.cliff) +
            beneficiary.TGEAmount -
            beneficiary.totalAmountHasBeenWithdrawn;
    }

    function getContractInfo()
        public
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _isStarted,
            _startedTime,
            _splitDuration,
            _splitCount,
            _vestingSchedulesInitializedAmount,
            _vestingSchedulesInitializedAmountLeft
        );
    }

    function getBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function getToken() public view returns (address) {
        return address(_token);
    }
}
