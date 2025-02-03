// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IAccessControlEnumerable } from '@oz-v5/access/extensions/IAccessControlEnumerable.sol';

/**
 * @title ITreasuryStorageV1
 * @notice Interface definition for the TreasuryStorageV1
 */
interface ITreasuryStorageV1 {
  struct HistoryResponse {
    uint48 timestamp;
    uint208 amount;
    bool sign;
  }

  /**
   * @notice Returns the current holdings of the reward token for the MatrixVault
   * @param matrixVault The MatrixVault address
   * @param reward The reward token address
   */
  function balances(address matrixVault, address reward) external view returns (uint256);

  /**
   * @notice Returns the management log histories of the reward token for the MatrixVault
   * @param matrixVault The MatrixVault address
   * @param reward The reward token address
   * @param offset The offset to start from
   * @param size The number of logs to return
   */
  function history(address matrixVault, address reward, uint256 offset, uint256 size)
    external
    view
    returns (HistoryResponse[] memory);
}

/**
 * @title ITreasury
 * @notice Interface for the Treasury reward handler
 */
interface ITreasury is IAccessControlEnumerable, ITreasuryStorageV1 {
  event RewardDispatched(address indexed matrixVault, address indexed reward, address indexed from, uint256 amount);
  event RewardHandled(address indexed matrixVault, address indexed reward, address indexed handler, uint256 amount);

  error ITreasury__InsufficientBalance();

  /**
   * @notice Checks if the specified dispatcher is allowed to call `handleReward`
   */
  function isDispatchable(address dispatcher) external view returns (bool);

  /**
   * @notice Handles the distribution of rewards for the specified vault and reward
   * @dev This method can only be called by the account that is allowed to dispatch rewards by `isDispatchable`
   */
  function handleReward(address matrixVault, address reward, uint256 amount) external;

  /**
   * @notice Dispatches reward distribution with stacked rewards
   * @param matrixVault The MatrixVault address
   * @param reward The reward token address
   * @param amount The reward amount
   * @param handler The reward handler address
   * @param metadata The auxiliary data for the reward handler (TODO:ray)
   */
  function dispatch(address matrixVault, address reward, uint256 amount, address handler, bytes calldata metadata)
    external;
}
