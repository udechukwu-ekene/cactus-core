//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseToken is Pausable, Ownable {
    uint256 public constant AIRDROP_AMOUNT = 120e4 * 10**18; //1,200,000
    uint256 public constant WHITELIST_ALLOCATION = 48e5 * 10**18; //4,800,000
    uint256 public constant PUBLIC_SUPPLY = 6e6 * 10**18; //6,000,000
    uint256 public constant LIQUIDITY_ALLOCATION = 6e6 * 10**18; //6,000,000
    uint256 public constant TEAM_ALLOCATION = 12e6 * 10**18; //12,000,000
    uint256 public constant MARKETING_RESERVE_AMOUNT = 6e6 * 10**18; //6,000,000
    uint256 public constant STAKING_ALLOCATION = 84e6 * 10**18; //84,000,000

    uint256 private _cap = 120e6 * 10**18; //120,000,000

    uint256 public liquidityReserveUsed;

    address public treasuryContract;

    mapping(address => bool) public operators;

    event TreasuryContractChanged(
        address indexed previusAAddress,
        address indexed newAddress
    );

    event OperatorUpdated(address indexed operator, bool indexed status);

    event TeamAddressChanged(
        address indexed previusAAddress,
        address indexed newAddress
    );

    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function pause() public onlyOperator {
        _pause();
    }

    function unpause() public onlyOperator {
        _unpause();
    }

    function updateOperator(address _operator, bool _status) public onlyOperator {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function setTreasuryAddress(address _newAddress) public onlyOperator whenNotPaused {
        emit TreasuryContractChanged(treasuryContract, _newAddress);
        treasuryContract = _newAddress;
    }

    function getOwner() external view returns (address) {
        return owner();
    }
}
