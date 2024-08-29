// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IMorpho, Id, MarketParams } from '../../../external/morpho/Morpho.sol';
import { SharesMathLib, MorphoBalancesLib } from '../../../external/morpho/MorphoLib.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';

contract MorphoStrategy is StdStrategy {
  using SafeERC20 for IERC20;
  using SharesMathLib for uint256;
  using MorphoBalancesLib for IMorpho;

  error DepositFailed();
  error WithdrawFailed();

  IMorpho internal immutable _morpho;

  constructor(IMorpho morpho_) StdStrategy() {
    _morpho = morpho_;
  }

  function strategyName() public pure override returns (string memory) {
    return 'morpho';
  }

  function morpho() external view returns (IMorpho) {
    return _morpho;
  }

  function _totalBalance(bytes memory context) internal view override returns (uint256) {
    MarketParams memory marketParams = _verifyMarketParams(context);
    return _morpho.expectedSupplyBalance(marketParams, address(this));
  }

  function _verifyMarketParams(bytes memory context) private view returns (MarketParams memory marketParams) {
    IERC20 asset_ = _asset();
    Id id = abi.decode(context, (Id));
    marketParams = _morpho.idToMarketParams(id);
    if (marketParams.loanToken != address(asset_)) revert StdError.InvalidAddress('loanToken');
    return marketParams;
  }

  function _deposit(uint256 amount, bytes memory context) internal override {
    MarketParams memory marketParams = _verifyMarketParams(context);

    IERC20(marketParams.loanToken).forceApprove(address(_morpho), amount);
    (uint256 assetsSupplied,) = _morpho.supply(
      marketParams,
      amount, // amount
      0, // share
      address(this), // behalf
      ''
    );
    if (assetsSupplied != amount) revert DepositFailed();
  }

  function _withdraw(uint256 amount, bytes memory context) internal override {
    MarketParams memory marketParams = _verifyMarketParams(context);

    (uint256 assetsWithdrawn,) = _morpho.withdraw(
      marketParams,
      amount, // amount
      0, // share
      address(this), // behalf
      address(this) // recipient
    );
    if (assetsWithdrawn != amount) revert WithdrawFailed();
  }
}
