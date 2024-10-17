// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';

import { IStrategy } from './IStrategy.sol';

interface ITeFiStrategy is IStrategy {
  error ITeFiStrategy__InsufficientDeposit();

  /**
   * @notice query the name of the DeFi
   */
  function defiName() external view returns (string memory);

  /**
   * @notice main entry point to claim rewards into the strategy
   *
   * @param asset_ the address of the reward token contract address
   *
   * @param amount the amount of reward to claim
   */
  function claim(address asset_, uint256 amount) external;
}
