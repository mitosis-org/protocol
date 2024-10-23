// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor } from './IRewardDistributor.sol';

/**
 * @title ITWABRewardDistributorStorageV1
 * @notice Interface definition for the TWABRewardDistributorStorageV1
 */
interface ITWABRewardDistributorStorageV1 {
  event TWABPeriodSet(uint48 indexed period);
  event RewardPrecisionSet(uint256 indexed precision);

  /**
   * @notice Error thrown when attempting to set a zero TWAB period.
   */
  error ITWABRewardDistributorStorageV1__ZeroPeriod();

  /**
   * @notice Returns the current TWAB period.
   * @return The TWAB period as a uint48.
   */
  function twabPeriod() external view returns (uint48);

  /// @dev Returns the reward precision.
  function rewardPrecision() external view returns (uint256);
}

/**
 * @title ITWABRewardDistributor
 * @notice Interface for the TWAB reward distributor
 */
interface ITWABRewardDistributor is IRewardDistributor, ITWABRewardDistributorStorageV1 {
  /**
   * @notice Error thrown when there's insufficient reward for distribution.
   */
  error ITWABRewardDistributor__InsufficientReward();

  error ITWABRewardDistributor__BatchTimestampAlreadyClaimed();
  error ITWABRewardDistributor__BatchTimestampAlreadyFinalized();
  error ITWABRewardDistributor__BatchTimestampNotFinalized();

  /**
   * @notice Gets the first batch timestamp for a given EOL Vault and reward.
   * @param eolVault The address of the EOL Vault contract.
   * @param reward The address of the reward token.
   */
  function getFirstBatchTimestamp(address eolVault, address reward) external view returns (uint48);

  /**
   * @notice Gets the last claimed batch timestamp for a given EOL Vault, reward and account.
   * @param eolVault The address of the EOL Vault contract.
   * @param account The address of the account.
   * @param reward The address of the reward token.
   */
  function getLastClaimedBatchTimestamp(address eolVault, address account, address reward)
    external
    view
    returns (uint48);

  /**
   * @notice Gets the last finalized batch timestamp for a given EOL Vault.
   * @param eolVault The address of the EOL Vault contract.
   */
  function getLastFinalizedBatchTimestamp(address eolVault) external view returns (uint48);

  /**
   * @notice Gets the total claimable amount for all batch timestamps until the specified timestamp.
   * @param eolVault The address of the EOL Vault contract.
   * @param account The address of the account.
   * @param reward The address of the reward token.
   * @param until The timestamp until which to check claimable amount.
   */
  function claimableAmountUntil(address eolVault, address account, address reward, uint48 until)
    external
    view
    returns (uint256);

  /**
   * @notice Claims rewards for all batch timestamps until the specified timestamp.
   * @param eolVault The address of the EOL Vault contract.
   * @param receiver The address of the receiver.
   * @param reward The address of the reward token.
   * @param until The timestamp until which to claim rewards.
   * @return lastClaimedBatchTimestamp The last claimed batch timestamp.
   */
  function claimUntil(address eolVault, address receiver, address reward, uint48 until)
    external
    returns (uint48 lastClaimedBatchTimestamp);
}
