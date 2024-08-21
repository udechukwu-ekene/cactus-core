//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./extensions/BaseToken.sol";

contract CactusToken is Context, IERC20, BaseToken, IERC20Metadata {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    uint256 public maxTxFeeBps = 2500;

    address public teamAddress;
    address public liquidityAddress = address(this);

    uint256 public _taxFee;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _marketingFee;
    uint256 private _previousMarketingFee = _marketingFee;

    constructor(address _teamAddress, uint16 taxFeeBps_, uint16 liquidityFeeBps_, uint16 marketingFeeBps_) {
        uint256 initialMint = WHITELIST_ALLOCATION.add(PUBLIC_SUPPLY).add(AIRDROP_AMOUNT).add(LIQUIDITY_ALLOCATION);
        _tTotal = initialMint;
        uint256 _max = MAX.div(1e36);
        _rTotal = ((_max - (_max % _tTotal)));

        _taxFee = taxFeeBps_;
        _previousTaxFee = _taxFee;

        _liquidityFee = liquidityFeeBps_;
        _previousLiquidityFee = _liquidityFee;

        teamAddress = _teamAddress;
        _marketingFee = marketingFeeBps_;
        _previousMarketingFee = _marketingFee;

        _rOwned[owner()] = _rTotal;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[liquidityAddress] = true;

        operators[owner()] = true;
        emit OperatorUpdated(owner(), true);
    }

    function name() public view virtual override returns (string memory) {
        return "Cactus";
    }

    function symbol() public view virtual override returns (string memory) {
        return "CACTT";
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view virtual override returns (uint256){
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool){
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
         _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount, , , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function setTaxFeePercent(uint256 taxFeeBps) public onlyOperator {
        require(taxFeeBps >= 0 && taxFeeBps <= maxTxFeeBps, "Invalid bps");
        _taxFee = taxFeeBps;
    }

    function setLiquidityFeePercent(uint256 liquidityFeeBps) public onlyOperator {
        _liquidityFee = liquidityFeeBps;
        require(_liquidityFee + _marketingFee <= maxTxFeeBps, "Invalid bps");
    }

    function setMarketingFeePercent(uint256 marketingFeeBps) public onlyOperator {
        _marketingFee = marketingFeeBps;
        require(_liquidityFee + _marketingFee <= maxTxFeeBps, "Invalid bps");
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,     "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOperator {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) public onlyOperator {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender, address recipient, uint256 tAmount
    ) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeMarketingFee(tMarketing);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount
    ) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeMarketingFee(tMarketing);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeMarketingFee(tMarketing);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeMarketingFee(tMarketing);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual whenNotPaused {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        bool takeFee = true;

        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            takeFee = false;
        }
        _tokenTransfer(sender, recipient, amount, takeFee);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if (!takeFee) removeAllFee();
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) restoreAllFee();
    }

    function burn(address account, uint256 amount) public onlyOperator {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 _rate = _getRate();
        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _tTotal = _tTotal.sub(amount);
        _rTotal = _rTotal.sub(amount.mul(_rate));
        _rOwned[account] = _rOwned[account].sub(amount.mul(_rate));
        if (_isExcluded[account]) {
            _tOwned[account] = _tOwned[account].sub(amount);
        }
        emit Transfer(account, address(0), amount);
    }

    function mint(address to, uint256 amount) external onlyOperator {
        _mint(to, amount);
    }

    function _mint(address receiver, uint256 amount) internal virtual {
        require(totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        require(receiver != address(0), "ERC20: mint to the zero address");
        uint256 _rate = _getRate();
        _tTotal = _tTotal.add(amount);
        _rTotal = _rTotal.add(amount.mul(_rate));
        _rOwned[receiver] = _rOwned[receiver].add(amount.mul(_rate));
        if (_isExcluded[receiver]) {
            _tOwned[receiver] = _tOwned[receiver].add(amount);
        }
        emit Transfer(address(0), receiver, amount);
    }

    function excludeFromFee(address account) public onlyOperator {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOperator {
        _isExcludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tMarketingFee = calculateMarketingFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(
            tMarketingFee
        );
        return (tTransferAmount, tFee, tLiquidity, tMarketingFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount,uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount, tFee, tLiquidity, tMarketing, _getRate()
        );
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tMarketing);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rMarketing = tMarketing.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(
            rMarketing
        );
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[liquidityAddress] = _rOwned[liquidityAddress].add(rLiquidity);
        if (_isExcluded[liquidityAddress])
            _tOwned[liquidityAddress] = _tOwned[liquidityAddress].add(tLiquidity);
    }

    function transferLiquidityOwnership(address newAddress) public onlyOperator {
      uint256 balance = balanceOf(liquidityAddress);
      if(balance > 0){
        _approve(liquidityAddress, _msgSender(), balance);
        transferFrom(liquidityAddress, newAddress, balance);
      }
      liquidityAddress = newAddress;
      excludeFromFee(liquidityAddress);
    }

    function _takeMarketingFee(uint256 tMarketing) private {
        if (tMarketing > 0) {
            uint256 currentRate = _getRate();
            uint256 rMarketing = tMarketing.mul(currentRate);
            _rOwned[teamAddress] = _rOwned[teamAddress].add(rMarketing);
            if (_isExcluded[teamAddress])
                _tOwned[teamAddress] = _tOwned[teamAddress].add(tMarketing);
            emit Transfer(_msgSender(), teamAddress, tMarketing);
        }
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(maxTxFeeBps);
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(maxTxFeeBps);
    }

    function calculateMarketingFee(uint256 _amount) private view returns (uint256) {
        if (teamAddress == address(0)) return 0;
        return _amount.mul(_marketingFee).div(maxTxFeeBps);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0 && _marketingFee == 0) return;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousMarketingFee = _marketingFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _marketingFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _marketingFee = _previousMarketingFee;
    }

    function setTeamAddress(address _newAddress) public onlyOperator {
        require(_newAddress != address(0), "setDevAddress: ZERO");
        emit TeamAddressChanged(teamAddress, _newAddress);
        teamAddress = _newAddress;
    }
}
