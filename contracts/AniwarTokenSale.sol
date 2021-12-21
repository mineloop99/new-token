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
    address public constant burnAddress =
        0x000000000000000000000000000000000000dEaD;

    struct Buyer {
        uint256 totalAllowedAmount;
        uint256 totalAmount;
        // total amount of tokens has been withdrawn at the current time
        uint256 amountHasBeenWithdrawn;
        // Initiliazed
        bool initialized;
    }

    mapping(address => Buyer) public buyers;
    uint256 public startedTime;
    uint256 public totalSold;
    uint256 public splitDuration;
    uint256 public price;
    uint256 public constant splitCount = 12;
    uint256 public initTokenAmount;
    address[] public tokensAllowed;
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

    modifier tokenAllowed(address tokenAddress_) {
        bool isAllowed = false;
        for (uint256 i = 0; i < tokensAllowed.length; i++) {
            if (tokensAllowed[i] == tokenAddress_) {
                _;
                isAllowed = true;
            }
        }
        require(isAllowed, "Not Allowed Token");
    }

    /*
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     * @param splitDuration_ time for end split
     */

    constructor(
        address token_,
        uint256 splitDuration_,
        uint256 price_,
        address[] memory tokensAllowed_,
        uint256 _initTokenAmount
    ) {
        require(token_ != address(0x0), "Token address wrong!");
        price = price_;
        tokensAllowed = tokensAllowed_;
        initTokenAmount = _initTokenAmount;
        _token = IERC20(token_);
        isStarted = false;
        splitDuration = splitDuration_;
    }

    function startSaleSchedule(uint256 _time)
        public
        onlyOwner
        onlyIfSaleScheduleNotStarted
    {
        isStarted = true;
        startedTime = _time;
    }

    function addBuyer(address buyerAddress, uint256 amount) public onlyOwner {
        Buyer storage buyer = buyers[buyerAddress];
        if (!buyer.initialized) {
            buyer.initialized = true;
        }
        buyer.totalAllowedAmount = buyer.totalAllowedAmount + amount;
    }

    function buyToken(address _allowedToken, uint256 tokenAmount)
        public
        tokenAllowed(_allowedToken)
        nonReentrant
    {
        Buyer storage buyer = buyers[msg.sender];
        require(
            buyer.totalAllowedAmount >= tokenAmount,
            "Allowed amount insufficent!"
        );
        require(
            initTokenAmount - totalSold >= tokenAmount,
            "Amount left insufficent!"
        );
        uint256 allowedTokenAmount = tokenAmount * price;
        IERC20 token = IERC20(_allowedToken);
        require(
            token.allowance(msg.sender, address(this)) >= allowedTokenAmount,
            "Allowance amount insufficent!"
        );
        token.transferFrom(msg.sender, address(this), allowedTokenAmount);
        totalSold = totalSold + tokenAmount * 1 ether;
        buyer.totalAmount = buyer.totalAmount + tokenAmount * 1 ether;
        buyer.totalAllowedAmount =
            buyer.totalAllowedAmount -
            tokenAmount *
            1 ether;
    }

    function release() public onlyIfSaleScheduleStarted nonReentrant {
        Buyer storage buyer = buyers[msg.sender];
        uint256 _amount = calculateWithdrawableAmount(msg.sender);
        require(_amount > 0, "Amount insufficents");
        require(buyer.initialized, "Wut?");
        address payable beneficiaryPayable = payable(msg.sender);
        _token.safeTransfer(beneficiaryPayable, _amount);
        buyer.amountHasBeenWithdrawn = buyer.amountHasBeenWithdrawn + _amount;
        emit Released(_amount);
    }

    function calculateWithdrawableAmount(address _buyerAddress)
        public
        view
        returns (uint256)
    {
        Buyer memory _buyer = buyers[_buyerAddress];
        uint256 currentSplit = getSplitByTime(getCurrentTime());
        uint256 totalWithdrawable = (_buyer.totalAmount * currentSplit) /
            splitCount;
        return totalWithdrawable - _buyer.amountHasBeenWithdrawn;
    }

    function burnContractBalanceLeft() public nonReentrant onlyOwner {
        for (uint256 i = 0; i < tokensAllowed.length; i++) {
            uint256 balance = IERC20(tokensAllowed[i]).balanceOf(
                (address(this))
            );
            if (balance > 0) {
                IERC20(tokensAllowed[i]).transfer(burnAddress, balance);
            }
        }
    }

    function getSplitByTime(uint256 _time) public view returns (uint256) {
        if (_time < startedTime || !isStarted) {
            return 0;
        }
        if ((_time - startedTime) / splitDuration >= splitCount) {
            return splitCount;
        }
        return 1 + (_time - startedTime) / splitDuration;
    }

    function getBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function getTimes() public view returns (uint256[splitCount] memory) {
        uint256[splitCount] memory times;
        for (uint256 i = 0; i < splitCount; i++) {
            times[i] = startedTime + (splitDuration * i);
        }
        return times;
    }
}
