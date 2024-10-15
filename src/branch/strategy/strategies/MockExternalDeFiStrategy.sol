// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IMockExternalDeFiStrategy } from '../../../interfaces/branch/strategy/IMockExternalDeFiStrategy.sol';
import { IStrategy } from '../../../interfaces/branch/strategy/IStrategy.sol';
import { StdError } from '../../../lib/StdError.sol';
import { MockExternalDeFi } from './MockExternalDeFi.sol';
import { StdStrategy } from './StdStrategy.sol';

contract MockExternalDeFiStrategy is IMockExternalDeFiStrategy, StdStrategy {
  using SafeERC20 for IERC20;

  MockExternalDeFi internal immutable _mockExternalDeFi;

  constructor(MockExternalDeFi _mockExternalDeFi_) StdStrategy() {
    _mockExternalDeFi = mockExternalDeFi_;
  }

  function strategyName() public pure override(StdStrategy, IStrategy) returns (string memory) {
    return 'MockExternalDeFi';
  }

  function defiName() external view returns (string memory) {
    return _mockExternalDeFi.name();
  }

  function _asset() internal view override returns (IERC20) {
    return _mockExternalDeFi.asset();
  }

  function claim(address asset_, uint256 amount) external {
    _mockExternalDeFi.claim(asset_, amount);
  }

  function _totalBalance(bytes memory) internal view override returns (uint256) {
    return IERC20(_asset()).balanceOf(address(_mockExternalDeFi));
  }

  function _deposit(uint256 amount, bytes memory) internal override {
    IERC20(_asset()).transfer(address(_mockExternalDeFi), amount);
  }

  function _withdraw(uint256 amount, bytes memory) internal override {
    _mockExternalDeFi.withdraw(amount);
  }
}
