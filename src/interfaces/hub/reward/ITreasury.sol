// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IAccessControlEnumerable } from '@oz-v5/access/extensions/IAccessControlEnumerable.sol';

import { IRewardHandler } from './IRewardHandler.sol';

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
   * @notice Returns the current holdings of the reward token for the EOLVault
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @return balance The current holdings of the reward token
   */
  function balances(address eolVault, address reward) external view returns (uint256 balance);

  /**
   * @notice Returns the management log history of the reward token for the EOLVault
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param offset The offset to start from
   * @param size The number of logs to return
   * @return history_ The management log history of the reward token
   */
  function history(address eolVault, address reward, uint256 offset, uint256 size)
    external
    view
    returns (HistoryResponse[] memory history_);
}

/**
 * @title ITreasury
 * @notice Interface for the Treasury reward handler
 */
interface ITreasury is IRewardHandler, IAccessControlEnumerable, ITreasuryStorageV1 {
  event RewardDispatched(address indexed eolVault, address indexed reward, address indexed from, uint256 amount);
  event RewardHandled(address indexed eolVault, address indexed reward, address indexed handler, uint256 amount);

  error ITreasury__InsufficientBalance();

  /**
   * @notice Dispatches reward distribution with stacked rewards
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param amount The reward amount
   * @param handler The reward handler address
   * @param metadata The auxiliary data for the reward handler
   */
  function dispatch(address eolVault, address reward, uint256 amount, address handler, bytes calldata metadata)
    external;
}
