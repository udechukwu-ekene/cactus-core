//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ICactusToken.sol";

contract CactusTreasury is Ownable {
    using SafeMath for uint256;

    ICactusToken public cactt;

    address public stakingContract;
    address public rewardingContract;

    uint256 public aidropDistributed;
    uint256 public stakingReserveUsed;
    uint256 public teamReserveUsed;
    uint256 public marketReserveUsed;

    mapping(address => bool) public operators;
    bool private _isRegisterAirdropDistribution;

    constructor(ICactusToken _cactt) {
        cactt = _cactt;
        operators[owner()] = true;
        emit OperatorUpdated(owner(), true);
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "caller is not the operator");
        _;
    }

    event OperatorUpdated(address indexed operator, bool indexed status);

    event StakingAddressChanged(
        address indexed previusAAddress,
        address indexed newAddress
    );

    event RewardingContractChanged(
        address indexed previusAAddress,
        address indexed newAddress
    );

    function balance() public view returns (uint256) {
        return cactt.balanceOf(address(this));
    }

    function burn(uint256 amount) public onlyOperator {
        cactt.burn(address(this), amount);
    }

    function mint(address _account, uint256 amount) public onlyOperator {
        cactt.mint(_account, amount);
    }

    function setCACTT(ICactusToken _newCactt) public onlyOperator {
        cactt = _newCactt;
    }

    function distributeAirdrop(address _receiver, uint256 _value)
        public
        onlyOwner
    {
        require(_isRegisterAirdropDistribution, "not registered ");
        aidropDistributed = aidropDistributed.add(_value);
        require(aidropDistributed <= cactt.AIRDROP_AMOUNT(), "exceeds max");
        cactt.mint(_receiver, _value);
    }

    function updateOperator(address _operator, bool _status)
        public
        onlyOperator
    {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function registerAirdropDistribution() public onlyOperator {
        require(!_isRegisterAirdropDistribution, "Already registered");
        _isRegisterAirdropDistribution = true;
    }

    function mintStakingReward(address _recipient, uint256 _amount)
        public
        onlyOperator
    {
        stakingReserveUsed = stakingReserveUsed.add(_amount);
        if (stakingReserveUsed <= cactt.STAKING_ALLOCATION()) {
            mint(_recipient, _amount);
        }
    }

    function teamMint(uint256 _amount) public onlyOperator {
        teamReserveUsed = teamReserveUsed.add(_amount);
        if (teamReserveUsed <= cactt.TEAM_ALLOCATION()) {
            mint(cactt.teamAddress(), _amount);
        }
    }

    function setStakingAddress(address _newAddress) public onlyOperator {
        emit StakingAddressChanged(stakingContract, _newAddress);
        stakingContract = _newAddress;
        updateOperator(stakingContract, true);
    }

    function initializeReward(address _rewardContract) public onlyOperator {
        setStakingAddress(_rewardContract);
        marketReserveUsed = marketReserveUsed.add(cactt.MARKETING_RESERVE_AMOUNT());
        if (marketReserveUsed <= cactt.MARKETING_RESERVE_AMOUNT()) {
            mint(_rewardContract, cactt.MARKETING_RESERVE_AMOUNT());
        }
    }

    function setRewardingContractAddress(address _newAddress)
        public
        onlyOperator
    {
        emit RewardingContractChanged(rewardingContract, _newAddress);
        rewardingContract = _newAddress;
    }
}
