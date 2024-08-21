//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICactusToken.sol";

contract CactusPrivateSale is Ownable {
    using SafeMath for uint256;

    ICactusToken public cactt;
    address public payableAddress;

    mapping(address => HolderInfo) private _privatesaleInfo;

    bool public openPrivatesale = false;

    address[] private _privatesale;

    uint256 public privatesaleDistributed;
    uint256 private _newPaymentInterval = 2592000;
    uint256 private _privatesaleHoldingCap = 96000 * 10**18;
    uint256 public _minimumPruchaseInBNB = 2 * 10**18; // 2BNB
    uint256 private _cattPerBNB = 9600; // current price as per the time of private sale

    mapping(address => bool) public operators;

    struct HolderInfo {
        uint256 total;
        uint256 monthlyCredit;
        uint256 amountLocked;
        uint256 nextPaymentUntil;
        uint256 initial;
        bool payedInitial;
    }

    constructor(ICactusToken _cactt, address _payableAddress) {
        cactt = _cactt;
        payableAddress = _payableAddress;
        operators[owner()] = true;
        emit OperatorUpdated(owner(), true);
    }

    event PrivatesaleStatusChanged(
        bool indexed previusState,
        bool indexed newState
    );

    function setCACTT(ICactusToken _newCactt) public onlyOwner {
        cactt = _newCactt;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    event OperatorUpdated(address indexed operator, bool indexed status);

    function registerPrivatesale(address _account) external payable {
        require(openPrivatesale, "Sale is not in session.");
        require(msg.value > 0, "Invalid amount of BNB sent!");
        uint256 _cattAmount = msg.value * _cattPerBNB;
        privatesaleDistributed = privatesaleDistributed.add(_cattAmount);
        HolderInfo memory holder = _privatesaleInfo[_account];
        if (holder.total <= 0) {
            _privatesale.push(_account);
        }
        require(
            msg.value >= _minimumPruchaseInBNB,
            "Minimum amount to buy is 2BNB"
        );
        require(
            _cattAmount <= _privatesaleHoldingCap,
            "You cannot hold more than 10BNB worth of DIBA"
        );
        require(
            cactt.WHITELIST_ALLOCATION() >= privatesaleDistributed,
            "Distribution reached its max"
        );
        require(
            _privatesaleHoldingCap >= holder.total.add(_cattAmount),
            "Amount exceeds holding limit!"
        );
        payable(payableAddress).transfer(msg.value);
        uint256 initialPayment = _cattAmount.div(2); // Release 50% of payment
        uint256 credit = _cattAmount.div(2);

        holder.total = holder.total.add(_cattAmount);
        holder.amountLocked = holder.amountLocked.add(credit);
        holder.monthlyCredit = holder.amountLocked.div(5); // divide amount locked to 5 months
        holder.nextPaymentUntil = block.timestamp.add(_newPaymentInterval);
        holder.payedInitial = false;
        holder.initial = initialPayment;
        _privatesaleInfo[_account] = holder;
    }

    function initialPaymentRelease() public onlyOperator {
        for (uint256 i = 0; i < _privatesale.length; i++) {
            HolderInfo memory holder = _privatesaleInfo[_privatesale[i]];
            if (!holder.payedInitial) {
                uint256 amount = holder.initial;
                holder.payedInitial = true;
                holder.initial = 0;
                _privatesaleInfo[_privatesale[i]] = holder;
                cactt.mint(_privatesale[i], amount);
            }
        }
    }

    function timelyPrivatesalePaymentRelease() public onlyOperator {
        for (uint256 i = 0; i < _privatesale.length; i++) {
            HolderInfo memory holder = _privatesaleInfo[_privatesale[i]];
            if (
                holder.amountLocked > 0 &&
                block.timestamp >= holder.nextPaymentUntil
            ) {
                holder.amountLocked = holder.amountLocked.sub(
                    holder.monthlyCredit
                );
                holder.nextPaymentUntil = block.timestamp.add(
                    _newPaymentInterval
                );
                _privatesaleInfo[_privatesale[i]] = holder;
                cactt.mint(_privatesale[i], holder.monthlyCredit);
            }
        }
    }

    function holderInfo(address _holderAddress)
        public
        view
        returns (HolderInfo memory)
    {
        return _privatesaleInfo[_holderAddress];
    }

    function changePayableAddress(address _payableAddress) public onlyOperator {
      payableAddress = _payableAddress;
    }

    function updateOperator(address _operator, bool _status)
        public
        onlyOperator
    {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function setMinimumCact(uint256 _amount) public onlyOperator {
        _minimumPruchaseInBNB = _amount;
    }

    function enablePrivatesale() public onlyOperator {
        if (!openPrivatesale) {
            emit PrivatesaleStatusChanged(false, true);
            openPrivatesale = true;
            uint256 privatesaleBalance = cactt.WHITELIST_ALLOCATION().sub(
                privatesaleDistributed
            );
            cactt.burn(owner(), privatesaleBalance);
        }
    }

    function closePrivatesale() public onlyOperator {
        emit PrivatesaleStatusChanged(true, false);
        openPrivatesale = false;
    }
}
