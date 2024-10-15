// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';

import { IStrategy } from './IStrategy.sol';

interface IMockExternalDeFiStrategy is IStrategy {
  error IMockExternalDeFiStrategy__InsufficientDeposit();

  /**
   * @notice TODO
   *
   * @dev TODO
   */
  function defiName() external view returns (string memory);

  /**
   * @notice TODO
   *
   * @dev TODO
   *
   * @param asset_ TODO
   *
   * @param amount TODO
   */
  function claim(address asset_, uint256 amount) external;
}
