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

  error ITWABRewardDistributorStorageV1__ZeroPeriod();

  /// @dev Returns the TWAB period.
  function twabPeriod() external view returns (uint48);

  /// @dev Returns the reward precision.
  function rewardPrecision() external view returns (uint256);
}

/**
 * @title ITWABRewardDistributor
 * @notice Interface for the TWAB reward distributor
 */
interface ITWABRewardDistributor is IRewardDistributor, ITWABRewardDistributorStorageV1 {
  error ITWABRewardDistributor__InsufficientReward();
  error ITWABRewardDistributor__InvalidTWABCriteria();
  error ITWABRewardDistributor__InvalidRewardedAt();

  /// @dev Returns the first batch timestamp. If it does not exist, returns zero.
  function getFirstBatchTimestamp(address twabCriteria, address asset) external view returns (uint48);
}
