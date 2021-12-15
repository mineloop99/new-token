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
    struct VestingSchedule {
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmountReleased;
        // total amount has been withdraw
        uint256 totalAmountHasBeenWithdrawn;
    }

    struct Beneficiary {
        uint256 vestingId;
        uint256 totalAmount;
        uint256 TGEAmount;
        uint256 totalAmountHasBeenWithdrawn;
        bool initialized;
    }

    bool private _isStarted;
    uint256 private _startTime;
    uint256 private immutable _splitDuration;
    uint256 private immutable _splitCounter;
    uint256 private _vestingIdCounter;
    uint256 private _vestingSchedulesInitializedAmount;
    uint256 private _vestingSchedulesInitializedAmountLeft;

    VestingSchedule[] public vestingSchedules;
    address[] private _beneficiariesAddress;
    mapping(address => Beneficiary) private _beneficiaries;

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
        uint256 splitCounter_,
        uint256 initializedAmount_
    ) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
        _splitDuration = splitDuration_;
        _splitCounter = splitCounter_;
        _vestingSchedulesInitializedAmount = initializedAmount_;
    }

    function getToken() public view returns (address) {
        return address(_token);
    }

    function createVestingSchedule(address _beneficiary, uint256 _amount)
        public
        onlyOwner
        onlyIfVestingScheduleNotStarted
    {
        require(
            _amount <= _vestingSchedulesInitializedAmountLeft,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_amount > 0, "TokenVesting: amount must be > 0");
        if (!_beneficiaries[_beneficiary].initialized) {
            Beneficiary storage beneficiary = _beneficiaries[_beneficiary];
            beneficiary.vestingId = _vestingIdCounter;
            beneficiary.initialized = true;
            _beneficiariesAddress.push(_beneficiary);
            vestingSchedules.push(
                VestingSchedule(_vestingIdCounter, _beneficiary, _amount, 0)
            );
            _vestingIdCounter++;
        } else {
            VestingSchedule storage vestingSchedule = vestingSchedules[
                _beneficiaries[_beneficiary].vestingId
            ];
            vestingSchedule.totalAmountReleased =
                vestingSchedule.totalAmountReleased +
                _amount;
        }
        _vestingSchedulesInitializedAmountLeft =
            _vestingSchedulesInitializedAmountLeft -
            _amount;
    }

    function startAllSchedule(uint256 _time)
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
        _startTime = getCurrentTime() + _time;
        emit Begin();
    }

    function setInitTotalAmount(uint256 _amount)
        public
        onlyOwner
        onlyIfVestingScheduleNotStarted
    {
        require(_amount > 0, "Amount must be > 0!");
        require(
            _amount <= _token.balanceOf(address(this)),
            "Amount exceeds balance!"
        );
        require(
            _amount >=
                _vestingSchedulesInitializedAmount -
                    _vestingSchedulesInitializedAmountLeft,
            "Amount must be bigger than previous assigned!"
        );
        _vestingSchedulesInitializedAmountLeft =
            _amount -
            (_vestingSchedulesInitializedAmount -
                _vestingSchedulesInitializedAmountLeft);
        _vestingSchedulesInitializedAmount = _amount;
    }

    function release(uint256 _amount) public nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            _beneficiaries[address(msg.sender)].vestingId
        ];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        require(
            _beneficiaries[address(msg.sender)].initialized,
            "Not in Vesting Schedule"
        );
        require(_amount > 0, "Amount must be > 0");
        require(
            _amount <= calculateWithdrawable(address(msg.sender)),
            "Amount withdrawable insufficents!"
        );
        vestingSchedule.totalAmountHasBeenWithdrawn =
            vestingSchedule.totalAmountHasBeenWithdrawn +
            _amount;
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        _token.safeTransfer(beneficiaryPayable, _amount);
        emit Released(_amount);
    }

    function calculateWithdrawable(address _beneficiary)
        public
        view
        onlyIfVestingScheduleStarted
        returns (uint256)
    {
        Beneficiary memory beneficiary = _beneficiaries[_beneficiary];
        require(beneficiary.initialized, "Beneficiary does not exist!");
        VestingSchedule memory vestingSchedule = vestingSchedules[
            beneficiary.vestingId
        ];
        uint256 currentTime = getCurrentTime();
        uint256 currentSplit = (currentTime - _startTime) / _splitDuration;
        if (currentSplit >= _splitCounter) {
            currentSplit = _splitCounter;
        }
        if (currentSplit == 0) {
            currentSplit = 1;
        }
        return
            ((vestingSchedule.totalAmountReleased / _splitCounter) *
                currentSplit) - vestingSchedule.totalAmountHasBeenWithdrawn;
    }

    function withdrawContractBalance(uint256 _amount)
        public
        nonReentrant
        onlyOwner
    {
        require(
            !_isStarted || _amount <= _vestingSchedulesInitializedAmountLeft,
            "Amount exceeds balance and Init"
        );
        _vestingSchedulesInitializedAmount =
            _vestingSchedulesInitializedAmount -
            _amount;
        _vestingSchedulesInitializedAmountLeft =
            _vestingSchedulesInitializedAmountLeft -
            _amount;
        _token.safeTransfer(payable(owner()), _amount);
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
            uint256,
            uint256
        )
    {
        return (
            _isStarted,
            _startTime,
            _splitDuration,
            _splitCounter,
            _vestingIdCounter,
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
}
