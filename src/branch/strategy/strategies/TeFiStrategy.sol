// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IStrategy } from '../../../interfaces/branch/strategy/IStrategy.sol';
import { ITeFi } from '../../../interfaces/branch/strategy/ITeFi.sol';
import { ITeFiStrategy } from '../../../interfaces/branch/strategy/ITeFiStrategy.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';

contract TeFiStrategy is ITeFiStrategy, StdStrategy {
  using SafeERC20 for IERC20;

  ITeFi internal immutable _tefi;

  constructor(ITeFi tefi_) StdStrategy() {
    _tefi = tefi_;
  }

  function strategyName() public pure override(StdStrategy, IStrategy) returns (string memory) {
    return 'TeFi';
  }

  function tefi() external view returns (ITeFi) {
    return _tefi;
  }

  function defiName() external view returns (string memory) {
    return _tefi.name();
  }

  function _asset() internal view override returns (IERC20) {
    return _tefi.asset();
  }

  function claim(address asset_, uint256 amount) external {
    _tefi.claim(asset_, amount);
  }

  function _totalBalance(bytes memory) internal view override returns (uint256) {
    return IERC20(_asset()).balanceOf(address(_tefi));
  }

  function _deposit(uint256 amount, bytes memory) internal override {
    IERC20(_asset()).transfer(address(_tefi), amount);
  }

  function _withdraw(uint256 amount, bytes memory) internal override {
    _tefi.withdraw(amount);
  }
}
