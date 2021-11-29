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
        // started when true
        bool isStarted;
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // end of the vesting period in seconds
        uint256 end;
        // duration of the vesting period in seconds
        uint256 duration;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountReleased;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    // address of the ERC20 token
    IERC20 private immutable _token;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private beneficiariesVestingCount;

    event Released(uint256 amount);

    /**
     * @dev Reverts if no vesting schedule matches the passed identifier.
     */
    modifier onlyIfVestingScheduleStarted(bytes32 _vestingScheduleId) {
        require(
            vestingSchedules[_vestingScheduleId].isStarted == true,
            "Vesting is not Started Yet!"
        );
        _;
    }

    /**
     * @dev Reverts if the vesting schedule does not exist or has been revoked.
     */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 _vestingScheduleId) {
        require(
            vestingSchedules[_vestingScheduleId].isStarted == true,
            "Vesting is not Started Yet!"
        );
        require(
            vestingSchedules[_vestingScheduleId].revoked == false,
            "Vesting has been revoked Yet!"
        );
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(address token_) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev Returns the number of vesting schedules associated to a beneficiary.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
        public
        view
        returns (uint256)
    {
        return beneficiariesVestingCount[_beneficiary];
    }

    /**
     * @dev Returns the vesting schedule id at the given index.
     * @return the vesting id
     */
    function getVestingIdAtIndex(uint256 _index) public view returns (bytes32) {
        require(
            _index < getVestingSchedulesCount(),
            "TokenVesting: index out of range"
        );
        return vestingSchedulesIds[_index];
    }

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(
        address _beneficiary,
        uint256 _index
    ) public view returns (VestingSchedule memory) {
        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(_beneficiary, _index)
            ];
    }

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() public view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     */
    function getToken() public view returns (address) {
        return address(_token);
    }

    /*
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _revocable whether the vesting is revocable or not
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _duration,
        uint256 _amount
    ) public onlyOwner {
        require(
            this.getWithdrawableAmount() >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        bytes32 vestingScheduleId = this
            .computeNextVestingScheduleIdForBeneficiary(_beneficiary);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            false,
            _beneficiary,
            0,
            0,
            _duration,
            _amount,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
        vestingSchedulesIds.push(vestingScheduleId);
        beneficiariesVestingCount[_beneficiary] =
            beneficiariesVestingCount[_beneficiary] +
            1;
    }

    function startAllSchedule() public {
        for (
            uint256 vestingSchedulesIndex = 0;
            vestingSchedulesIndex < vestingSchedulesIds.length;
            vestingSchedulesIndex++
        ) {
            bytes32 _vestingScheduleId = vestingSchedulesIds[
                vestingSchedulesIndex
            ];
            if (!vestingSchedules[_vestingScheduleId].isStarted) {
                uint256 _currentTime = getCurrentTime();
                VestingSchedule memory _vestingSchedule = VestingSchedule(
                    true,
                    vestingSchedules[_vestingScheduleId].beneficiary,
                    _currentTime,
                    _currentTime +
                        vestingSchedules[_vestingScheduleId].duration,
                    vestingSchedules[_vestingScheduleId].duration,
                    vestingSchedules[_vestingScheduleId].amountReleased,
                    false
                );
                vestingSchedules[_vestingScheduleId] = _vestingSchedule;
            }
        }
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(bytes32 vestingScheduleId)
        public
        onlyOwner
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        uint256 vestedAmount = _computeReleasableAmount(vestingScheduleId);
        if (vestedAmount > 0) {
            release(vestingScheduleId, vestedAmount);
        }
        vestingSchedule.revoked = true;
    }

    /**
     * @notice Withdraw the specified amount if possible.
     * @param amount the amount to withdraw
     */
    function withdraw(uint256 amount) public nonReentrant onlyOwner {
        require(
            this.getWithdrawableAmount() >= amount,
            "TokenVesting: not enough withdrawable funds"
        );
        _token.safeTransfer(owner(), amount);
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */
    function release(bytes32 vestingScheduleId, uint256 amount)
        public
        nonReentrant
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingScheduleId);

        require(
            vestedAmount >= amount,
            "TokenVesting: cannot release tokens, not enough vested tokens"
        );

        vestingSchedule.amountReleased =
            vestingSchedule.amountReleased -
            amount;
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;
        _token.safeTransfer(beneficiaryPayable, amount);
        vestingSchedule.revoked = true;
        emit Released(amount);
    }

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */
    function computeReleasableAmount(bytes32 vestingScheduleId)
        public
        view
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        returns (uint256)
    {
        return _computeReleasableAmount(vestingScheduleId);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)) - vestingSchedulesTotalAmount;
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForBeneficiary(address _beneficiary)
        public
        view
        returns (bytes32)
    {
        return
            computeVestingScheduleIdForAddressAndIndex(
                _beneficiary,
                beneficiariesVestingCount[_beneficiary]
            );
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address _beneficiary,
        uint256 _index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_beneficiary, _index));
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(bytes32 vestingScheduleId)
        internal
        view
        returns (uint256)
    {
        VestingSchedule memory vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        if (
            (getCurrentTime() < vestingSchedule.end) ||
            vestingSchedule.isStarted == false ||
            vestingSchedule.revoked == true
        ) {
            return 0;
        } else {
            return vestingSchedule.amountReleased;
        }
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
