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
    struct VestingSchedule {
        // Vesting Schedule Id
        uint256 id;
        // beneficiary of tokens after they are released
        address beneficiary;
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmountReleased;
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmountWithdrawable;
        // total amount of token has been withdrawn
        uint256 totalAmountHasBeenWithdrawn;
    }

    struct Beneficiary {
        uint256 vestingId;
        // whether or not the vesting has been init
        bool initialized;
    }

    bool public isStarted;
    uint256 public startTime;
    uint256 public vestingIdCounter;
    uint256 private _vestingSchedulesTotalAmount;
    uint256 private _vestingSchedulesTotalAmountLeft;

    // address of the ERC20 token
    IERC20 private immutable _token;

    VestingSchedule[] public vestingSchedules;
    address[] private _beneficiariesAddress;
    mapping(address => Beneficiary) private _beneficiaries;

    event Released(uint256 amount);
    event Begin();

    modifier onlyIfVestingScheduleStarted() {
        require(isStarted, "Vesting is not Started Yet!");
        _;
    }
    modifier onlyIfVestingScheduleNotStarted() {
        require(!isStarted, "Vesting is Started!");
        _;
    }

    constructor(address token_) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
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
            _amount <= _vestingSchedulesTotalAmountLeft,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_amount > 0, "TokenVesting: amount must be > 0");
        if (!_beneficiaries[_beneficiary].initialized) {
            Beneficiary storage beneficiary = _beneficiaries[_beneficiary];
            beneficiary.vestingId = vestingIdCounter;
            beneficiary.initialized = true;
            _beneficiariesAddress.push(_beneficiary);
            vestingSchedules.push(
                VestingSchedule(vestingIdCounter, _beneficiary, _amount, 0, 0)
            );
            vestingIdCounter++;
        } else {
            VestingSchedule storage vestingSchedule = vestingSchedules[
                _beneficiaries[_beneficiary].vestingId
            ];
            vestingSchedule.totalAmountReleased =
                vestingSchedule.totalAmountReleased +
                _amount;
        }
        _vestingSchedulesTotalAmountLeft =
            _vestingSchedulesTotalAmountLeft -
            _amount;
    }

    function startAllSchedule()
        public
        onlyOwner
        onlyIfVestingScheduleNotStarted
    {
        isStarted = true;
        startTime = getCurrentTime();
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
                _vestingSchedulesTotalAmount - _vestingSchedulesTotalAmountLeft,
            "Amount must be bigger than previous assigned!"
        );
        _vestingSchedulesTotalAmountLeft =
            _amount -
            (_vestingSchedulesTotalAmount - _vestingSchedulesTotalAmountLeft);
        _vestingSchedulesTotalAmount = _amount;
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
            _amount <= vestingSchedule.totalAmountWithdrawable,
            "Amount withdrawable insufficents!"
        );
        vestingSchedule.totalAmountWithdrawable =
            vestingSchedule.totalAmountWithdrawable -
            _amount;
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        _token.safeTransfer(beneficiaryPayable, _amount);
        emit Released(_amount);
    }

    function getBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }
}
