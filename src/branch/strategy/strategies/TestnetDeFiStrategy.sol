// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IStrategy } from '../../../interfaces/branch/strategy/IStrategy.sol';
import { ITestnetDeFiStrategy } from '../../../interfaces/branch/strategy/ITestnetDeFiStrategy.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';
import { TestnetDeFi } from './TestnetDeFi.sol';

contract TestnetDeFiStrategy is ITestnetDeFiStrategy, StdStrategy {
  using SafeERC20 for IERC20;

  TestnetDeFi internal immutable _testnetDeFi;

  constructor(TestnetDeFi testnetDeFi_) StdStrategy() {
    _testnetDeFi = testnetDeFi_;
  }

  function strategyName() public pure override(StdStrategy, IStrategy) returns (string memory) {
    return 'TestnetDeFi';
  }

  function defiName() external view returns (string memory) {
    return _testnetDeFi.name();
  }

  function _asset() internal view override returns (IERC20) {
    return _testnetDeFi.asset();
  }

  function claim(address asset_, uint256 amount) external {
    _testnetDeFi.claim(asset_, amount);
  }

  function _totalBalance(bytes memory) internal view override returns (uint256) {
    return IERC20(_asset()).balanceOf(address(_testnetDeFi));
  }

  function _deposit(uint256 amount, bytes memory) internal override {
    IERC20(_asset()).transfer(address(_testnetDeFi), amount);
  }

  function _withdraw(uint256 amount, bytes memory) internal override {
    _testnetDeFi.withdraw(amount);
  }
}
