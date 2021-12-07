// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title TokenVesting
 */
contract AniwarTokenSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private immutable _token;

    struct SaleSchedule {
        // start time of the vesting period
        uint256 duration;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountReleased;
    }

    struct Beneficiary {
        uint256 id;
        // start time of the vesting period
        uint256 startedTime;
        // total amount of tokens has been withdrawn at the current time
        uint256 totalAmount;
        // total amount of tokens to be withdrawable at the current time
        uint256 amountWithdrawableTotal;
        // total amount of tokens has been withdrawn at the current time
        uint256 amountHasBeenWithdrawn;
        // currentSplit
        uint256 currentSplit;
        // Initiliazed
        bool initialized;
    }

    uint256 public beneficiariesCount;

    // Store address of Beneficiaries
    address[] private _beneficiariesAddress;
    mapping(address => Beneficiary) public beneficiaries;
    SaleSchedule[] private _saleSchedules;

    uint256 private _startedTime;
    uint256 private _totalAmountInitialized;
    uint256 private _totalAmountLeft;
    uint256 private _totalAmountAssignable;
    uint256 private _totalAmountWithdrawable;
    uint256 private _totalAmountHasBeenwithdrawn;

    uint256 private _currentSplit;
    uint256 private _splitDuration;
    // started when true
    bool public isStarted;

    event Released(uint256 amount);

    modifier onlyIfSaleScheduleStarted() {
        require(isStarted == true, "Sale has not Started Yet!");
        _;
    }

    modifier onlyIfSaleScheduleNotStarted() {
        require(isStarted == false, "Sale has Started!");
        _;
    }

    /*
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     * @param splitDuration_ time for end split
     */
    constructor(address token_, uint256 splitDuration_) {
        require(token_ != address(0x0), "Token address wrong!");
        _token = IERC20(token_);
        isStarted = false;
        _splitDuration = splitDuration_;
    }

    function startSaleSchedule() public onlyOwner {
        require(
            _token.balanceOf(address(this)) >= _totalAmountInitialized,
            "Balance not enought to start schedule"
        );
        isStarted = true;
        _startedTime = getCurrentTime();
        if (_beneficiariesAddress.length > 0) {
            for (
                uint256 beneficiaryIndex = 0;
                beneficiaryIndex < _beneficiariesAddress.length;
                beneficiaryIndex++
            ) {
                Beneficiary storage beneficiary = beneficiaries[
                    _beneficiariesAddress[beneficiaryIndex]
                ];
                beneficiary.startedTime = getCurrentTime();
            }
        }
    }

    function createSaleSchedule(uint256[] memory _amounts)
        public
        onlyOwner
        onlyIfSaleScheduleNotStarted
    {
        require(
            _checkAmountAgainstBalance(_amounts),
            "Total amount exceeds the balance!"
        );
        if (_saleSchedules.length == 0) {
            _totalAmountAssignable = _totalAmountAssignable + _amounts[0];
        }
        for (
            uint256 amountIndex = 0;
            amountIndex < _amounts.length;
            amountIndex++
        ) {
            require(
                _amounts[amountIndex] > 0,
                "There is an zero amount assign"
            );
            SaleSchedule memory _saleScheduleTemp = SaleSchedule(
                amountIndex * _splitDuration,
                _amounts[amountIndex]
            );
            _saleSchedules.push(_saleScheduleTemp);
            _totalAmountInitialized =
                _totalAmountInitialized +
                _amounts[amountIndex];
            _totalAmountLeft = _totalAmountLeft + _amounts[amountIndex];
        }
    }

    function addBeneficiary(address _beneficiaryAddress, uint256 _amount)
        public
        onlyOwner
    {
        updateContract();
        require(_saleSchedules.length > 0, "No schedule yet!");
        require(_amount > 0, "amount must be > 0!");
        require(
            _token.balanceOf(address(this)) >= _amount,
            "Current contract amount insufficent!"
        );
        require(
            _totalAmountAssignable >= _amount,
            "Total amount left insufficents"
        );
        _totalAmountLeft = _totalAmountLeft - _amount;
        _totalAmountAssignable = _totalAmountAssignable - _amount;
        Beneficiary storage beneficiary = beneficiaries[_beneficiaryAddress];
        if (isStarted) {
            if (beneficiary.startedTime == 0) {
                beneficiary.startedTime = getCurrentTime();
            }
        } else {
            beneficiary.startedTime = 0;
        }
        beneficiary.totalAmount = beneficiary.totalAmount + _amount;

        if (beneficiariesCount > 0) {
            if (beneficiary.id == 0 && !beneficiary.initialized) {
                _beneficiariesAddress.push(_beneficiaryAddress);
                beneficiary.id = beneficiariesCount;
                beneficiary.initialized = true;
                beneficiariesCount++;
            }
        } else {
            _beneficiariesAddress.push(_beneficiaryAddress);
            beneficiary.id = beneficiariesCount;
            beneficiary.initialized = true;
            beneficiariesCount++;
        }
        updateContract();
    }

    function releaseToken(uint256 _amount)
        public
        nonReentrant
        onlyIfSaleScheduleStarted
    {
        updateContract();
        Beneficiary storage beneficiary = beneficiaries[msg.sender];
        require(_amount > 0, "amount must be greater than 0!");
        require(
            beneficiary.amountWithdrawableTotal > 0,
            "You are not beneficiary or current withdrawable amount = 0!"
        );
        require(
            _totalAmountWithdrawable >= beneficiary.amountWithdrawableTotal,
            "current total withdrawable amount insufficent!"
        );
        require(
            _amount <= beneficiary.amountWithdrawableTotal,
            "current your withdrawable amount insufficent!"
        );
        _totalAmountWithdrawable = _totalAmountWithdrawable - _amount;
        _totalAmountHasBeenwithdrawn = _totalAmountHasBeenwithdrawn + _amount;
        beneficiary.amountWithdrawableTotal =
            beneficiary.amountWithdrawableTotal -
            _amount;
        beneficiary.amountHasBeenWithdrawn =
            beneficiary.amountHasBeenWithdrawn +
            _amount;
        address payable beneficiaryPayable = payable(msg.sender);
        _token.safeTransfer(beneficiaryPayable, _amount);
        emit Released(_amount);
    }

    function updateContract() public {
        if (isStarted) {
            uint256 _currentSplitTemp = getSplitByTime(getCurrentTime());
            if (_beneficiariesAddress.length > 0) {
                uint256 _totalAmountWithdrawableTemp = 0;
                for (
                    uint256 beneficiaryIndex = 0;
                    beneficiaryIndex < _beneficiariesAddress.length;
                    beneficiaryIndex++
                ) {
                    Beneficiary storage beneficiary = beneficiaries[
                        _beneficiariesAddress[beneficiaryIndex]
                    ];
                    uint256 _tempValue = _calculateSingleSplitAmount(
                        beneficiary
                    ) * _currentSplitTemp;
                    beneficiary.amountWithdrawableTotal = _tempValue;
                    beneficiary.currentSplit = _currentSplitTemp;
                    _totalAmountWithdrawableTemp =
                        _totalAmountWithdrawableTemp +
                        beneficiary.amountWithdrawableTotal;
                }
                _totalAmountWithdrawable = _totalAmountWithdrawableTemp;
            }
            if (_currentSplit < _currentSplitTemp) {
                if (_currentSplit == 0) {
                    _currentSplit = 1;
                }
                for (
                    uint256 splitIndex = _currentSplit;
                    splitIndex < _currentSplitTemp;
                    splitIndex++
                ) {
                    _totalAmountAssignable =
                        _totalAmountAssignable +
                        _saleSchedules[splitIndex].amountReleased;
                }
                _currentSplit = _currentSplitTemp;
            }
        }
    }

    function withdrawContractBalance(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be > 0!");
        require(
            !isStarted ||
                _amount <=
                (_token.balanceOf(address(this)) - _totalAmountInitialized),
            "Amount is > total Left or schedule is started!"
        );
        _token.transfer(address(msg.sender), _amount);
    }

    function _checkAmountAgainstBalance(uint256[] memory _amounts)
        private
        view
        returns (bool)
    {
        uint256 totalAmount = 0;
        for (
            uint256 amountIndex = 0;
            amountIndex < _amounts.length;
            amountIndex++
        ) {
            totalAmount = totalAmount + _amounts[amountIndex];
        }
        return _token.balanceOf(address(this)) >= totalAmount;
    }

    function _calculateSingleSplitAmount(Beneficiary memory _beneficiary)
        private
        view
        returns (uint256)
    {
        if (_beneficiariesAddress.length == 0 || !_beneficiary.initialized) {
            return 0;
        }
        if (_beneficiary.totalAmount / _saleSchedules.length == 0) {
            return 1;
        }
        return _beneficiary.totalAmount / _saleSchedules.length;
    }

    function removeSaleSchedule(uint256 index) internal onlyOwner {
        if (index >= _saleSchedules.length) return;

        for (uint256 i = index; i < _saleSchedules.length - 1; i++) {
            _saleSchedules[i] = _saleSchedules[i + 1];
        }
        delete _saleSchedules[_saleSchedules.length - 1];
    }

    function getSplitByTime(uint256 _time) public view returns (uint256) {
        if (_time < _startedTime || !isStarted) {
            return 0;
        }
        if ((_time - _startedTime) / _splitDuration >= _saleSchedules.length) {
            return _saleSchedules.length;
        }
        return 1 + (_time - _startedTime) / _splitDuration;
    }

    function getBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }
}
