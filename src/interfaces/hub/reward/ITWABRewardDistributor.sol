// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, IRewardDistributorStorage, DistributionType } from './IRewardDistributor.sol';

interface ITWABRewardDistributorStorageV1 is IRewardDistributorStorage {
  event TWABPeriodSet(uint48 indexed period);
  event RewardManagerSet(address indexed rewardManger);

  function rewardManager() external view returns (address);

  function twabPeriod() external view returns (uint48);
}

interface ITWABRewardDistributor is IRewardDistributor, ITWABRewardDistributorStorageV1 {
  error ITWABRewardDistributor__InsufficientReward();
  error ITWABRewardDistributor__InvalidERC20TWABSnapshots();
  error ITWABRewardDistributor__InvalidRewardedAt();
}
