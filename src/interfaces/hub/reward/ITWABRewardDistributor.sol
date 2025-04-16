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

  /**
   * @notice Error thrown when an invalid TWAB criteria is provided.
   */
  error ITWABRewardDistributor__InvalidTWABCriteria();

  /**
   * @notice Error thrown when an invalid rewarded-at timestamp is provided.
   */
  error ITWABRewardDistributor__InvalidRewardedAt();

  /**
   * @notice Gets the first batch timestamp for a given TWAB criteria and asset.
   * @param twabCriteria The address of the TWAB criteria contract.
   * @param asset The address of the asset.
   * @return The first batch timestamp as a uint48.
   */
  function getFirstBatchTimestamp(address twabCriteria, address asset) external view returns (uint48);
}
