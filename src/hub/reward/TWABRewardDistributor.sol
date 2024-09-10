// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { DistributionType } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { ITwabSnapshots } from '../../interfaces/twab/ITwabSnapshots.sol';
import { TwabSnapshotsUtils } from '../../lib/TwabSnapshotsUtils.sol';
import { LibDistributorRewardMetadata, RewardTWABMetadata } from './LibDistributorRewardMetadata.sol';

// move to reward or something. not `/eol`

contract TWABRewardDistributor {
  using LibDistributorRewardMetadata for RewardTWABMetadata;
  using LibDistributorRewardMetadata for bytes;

  DistributionType _distributionType;
  string _description;
  uint48 twabPeriod;

  // 1. We could return `claimbable` without `rewardedAt`
  // 2. We could call `claim` without `rewardedAt`
  // 3. We could one-time all asset claim

  struct Reward {
    address erc20TWABSnapshots;
    uint256 total;
    uint48 startsAt; // for store twabPeriod at point.
    // TODO: change this
    mapping(address account => uint256 claimed) claimed;
  }

  struct Asset {
    mapping(uint48 rewardedAt => Reward[] rewards) rewards;
  }

  mapping(address eolVault => mapping(address asset => Asset info)) _assets;

  constructor(uint48 period) {
    twabPeriod = period;
  }

  function description() external view returns (string memory) {
    return _description;
  }

  function distributionType() external view returns (DistributionType) {
    return _distributionType;
  }

  function claimable(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (bool)
  {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    // validation
    if (twabMetadata.erc20TWABSnapshots == address(0)) revert('invalid erc20TWABSnapshots');

    address erc20TWABSnapshots = twabMetadata.erc20TWABSnapshots;
    uint48 rewardedAt = twabMetadata.rewardedAt;

    Asset storage assetInfo = _assets[eolVault][asset];
    Reward[] storage rewards = assetInfo.rewards[rewardedAt];

    for (uint256 i = 0; i < rewards.length; i++) {
      Reward storage reward = rewards[i];
      uint256 userReward = _calculateUserReward(reward, account, rewardedAt);
      return userReward > 0;
    }

    return false;
  }

  function encodeMetadata(address erc20TWABSnapshots, uint48 rewardedAt) external view returns (bytes memory) {
    return RewardTWABMetadata({ erc20TWABSnapshots: erc20TWABSnapshots, rewardedAt: rewardedAt }).encode();
  }

  function calculateUserReward(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (uint256)
  {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    // validation
    if (twabMetadata.erc20TWABSnapshots == address(0)) revert('invalid erc20TWABSnapshots');

    address erc20TWABSnapshots = twabMetadata.erc20TWABSnapshots;
    uint48 rewardedAt = twabMetadata.rewardedAt;

    Asset storage assetInfo = _assets[eolVault][asset];
    Reward[] storage rewards = assetInfo.rewards[rewardedAt];

    uint256 userReward;

    for (uint256 i = 0; i < rewards.length; i++) {
      Reward storage reward = rewards[i];
      uint256 amount = _calculateUserReward(reward, account, rewardedAt);
      if (reward.claimed[account] == amount) continue;
      userReward += amount - reward.claimed[account];
    }

    return userReward;
  }

  // Mutative functions

  function claim(address eolVault, address asset, uint48 rewardedAt) external {
    Asset storage assetInfo = _assets[eolVault][asset];
    Reward[] storage rewards = assetInfo.rewards[rewardedAt];
    for (uint256 i = 0; i < rewards.length; i++) {
      Reward storage reward = rewards[i];
      uint256 userAmount = _calculateUserReward(reward, msg.sender, rewardedAt);

      reward.claimed[msg.sender] += userAmount;

      IERC20(asset).transfer(msg.sender, userAmount);
    }
  }

  function handleReward(address eolVault, address asset, uint256 amount, bytes calldata metadata)
    external /* onlyEOLRewardManager */
  {
    IERC20(asset).transferFrom(msg.sender, address(this), amount);

    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    // validation
    if (twabMetadata.erc20TWABSnapshots == address(0)) revert('invalid erc20TWABSnapshots');

    Asset storage assetInfo = _assets[eolVault][asset];

    assetInfo.rewards[twabMetadata.rewardedAt].push();
    uint256 rewardLength = assetInfo.rewards[twabMetadata.rewardedAt].length;

    Reward storage reward = assetInfo.rewards[twabMetadata.rewardedAt][rewardLength - 1];
    reward.erc20TWABSnapshots = twabMetadata.erc20TWABSnapshots;
    reward.total = amount;
    reward.startsAt = twabMetadata.rewardedAt - twabPeriod;
  }

  function _calculateUserReward(Reward storage reward, address account, uint48 rewardedAt)
    internal
    view
    returns (uint256)
  {
    uint48 startsAt = reward.startsAt;
    uint48 endsAt = rewardedAt;

    uint256 totalTWAB =
      TwabSnapshotsUtils.getTotalTwabByTimestampRange(ITwabSnapshots(reward.erc20TWABSnapshots), startsAt, endsAt);

    if (totalTWAB == 0) return 0;

    uint256 userTWAB = TwabSnapshotsUtils.getAccountTwabByTimestampRange(
      ITwabSnapshots(reward.erc20TWABSnapshots), account, startsAt, endsAt
    );

    uint256 userReward = (reward.total * userTWAB) / totalTWAB; // TODO: precision?
    return userReward - reward.claimed[account];
  }
}
