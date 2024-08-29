// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Context } from '@oz-v5/utils/Context.sol';

interface IStrategyDependency {
  function asset() external view returns (IERC20);
}

interface IStrategy is IStrategyDependency {
  event Deposit(address indexed adaptor, uint256 amount, bytes context);

  event Withdraw(address indexed adaptor, uint256 amount, bytes context);

  /**
   * @return self the address of the strategy itself
   */
  function self() external view returns (address);

  /**
   * @return strategyName the name of the strategy
   */
  function strategyName() external pure returns (string memory);

  /**
   * @return yes if the strategy is supporting async deposit
   */
  function isDepositAsync() external pure returns (bool);

  /**
   * @return yes if the strategy is supporting async withdraw
   */
  function isWithdrawAsync() external pure returns (bool);

  /**
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return totalBalance_ the total amount of asset that the strategy is managing
   */
  function totalBalance(bytes memory context) external view returns (uint256 totalBalance_);

  /**
   * @notice query withdrawable balance from the strategy
   *
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return availableBalance_ the amount of asset that can be withdrawn
   */
  function withdrawableBalance(bytes memory context) external view returns (uint256 availableBalance_);

  /**
   * @notice query pending deposit balance
   *
   * @dev if the strategy is not supporting async deposit, this function must return 0
   *
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return pendingDepositBalance_ the amount of asset that is pending to deposit
   */
  function pendingDepositBalance(bytes memory context) external view returns (uint256 pendingDepositBalance_);

  /**
   * @notice query pending withdraw balance
   *
   * @dev if the strategy is not supporting async withdraw, this function must return 0
   *
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return pendingWithdrawBalance_ the amount of asset that is pending to withdraw
   */
  function pendingWithdrawBalance(bytes memory context) external view returns (uint256 pendingWithdrawBalance_);

  /**
   * @notice simulates the deposit
   *
   * @param amount the amount of asset to simulate the deposit
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return deposited the amount of asset that will be deposited
   */
  function previewDeposit(uint256 amount, bytes memory context) external returns (uint256 deposited);

  /**
   * @notice simulates the withdraw
   */
  function previewWithdraw(uint256 amount, bytes memory context) external returns (uint256 withdrawn);

  /**
   * @notice requests a deposit to the strategy
   *
   * @param amount the amount of asset to deposit
   * @param context the auxiliary data of the deposit request such like position id or any other information
   *
   * @return ret the result of the deposit request like requestId or any other information
   */
  function requestDeposit(uint256 amount, bytes memory context) external returns (bytes memory ret);

  /**
   * @notice main entry point to deposit assets into the strategy
   */
  function deposit(uint256 amount, bytes memory context) external returns (uint256 deposited);

  /**
   * @notice requests a withdraw from the strategy
   *
   * @param amount the amount of asset to request withdraw
   * @param context the auxiliary data of the withdraw request such like position id or any other information
   *
   * @return ret the result of the withdraw request like requestId or any other information
   */
  function requestWithdraw(uint256 amount, bytes memory context) external returns (bytes memory ret);

  /**
   * @notice main entry point to withdraw assets into the strategy.
   * - If the withdraw is async, the withdraw function should be called after calling `requestWithdraw` function
   * - If the strategy cannot withdraw more than amount, The execution must be reverted
   *
   * @param amount the amount of asset to withdraw
   * @param context the auxiliary data of the withdraw request such like position id or any other information
   *
   * @dev the funds that are withdrawn from the strategy should be transferred to the vault directly.
   */
  function withdraw(uint256 amount, bytes memory context) external returns (uint256 withdrawn);
}
