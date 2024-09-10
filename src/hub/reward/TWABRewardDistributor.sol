// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { DistributionType } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';
import { LibDistributorRewardMetadata, RewardTWABMetadata } from './LibDistributorRewardMetadata.sol';
import { TWABRewardDistributorStorageV1 } from './TWABRewardDistributorStorageV1.sol';

contract TWABRewardDistributor is ITWABRewardDistributor, Ownable2StepUpgradeable, TWABRewardDistributorStorageV1 {
  using LibDistributorRewardMetadata for RewardTWABMetadata;
  using LibDistributorRewardMetadata for bytes;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address rewardManager_, uint48 twabPeriod_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();
    _setRewardManager($, rewardManager_);
    _setTWABPeriod($, twabPeriod_);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function encodeMetadata(address erc20TWABSnapshots, uint48 rewardedAt) external pure returns (bytes memory) {
    return RewardTWABMetadata({ erc20TWABSnapshots: erc20TWABSnapshots, rewardedAt: rewardedAt }).encode();
  }

  function claimable(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (bool)
  {
    return calculateUserReward(account, eolVault, asset, metadata) > 0;
  }

  function calculateUserReward(address account, address eolVault, address asset, bytes calldata metadata)
    public
    view
    returns (uint256)
  {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    _assertValidRewardMetadata(twabMetadata);

    uint48 rewardedAt = twabMetadata.rewardedAt;

    StorageV1 storage $ = _getStorageV1();

    RewardInfo[] storage rewards = _rewardInfos($, eolVault, asset, rewardedAt);
    uint256 totalReawrd = _calculateTotalReward(rewards, account, rewardedAt);

    Receipt storage receipt = _receipt($, account, eolVault, asset, rewardedAt);
    return totalReawrd - receipt.claimedAmount;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function setRewardManager(address rewardManager_) external onlyOwner {
    _setRewardManager(_getStorageV1(), rewardManager_);
  }

  function setTWABPeriod(uint48 period) external onlyOwner {
    _setTWABPeriod(_getStorageV1(), period);
  }

  function claim(address eolVault, address reward, bytes calldata metadata) external {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    _assertValidRewardMetadata(twabMetadata);

    AssetRewards storage assetRewards = _assetRewards(eolVault, reward);
    _claimAllReward(assetRewards, _msgSender(), reward, twabMetadata.rewardedAt);
  }

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    _assertValidRewardMetadata(twabMetadata);

    AssetRewards storage assetRewards = _assetRewards(eolVault, reward);
    _claimPartialReward(assetRewards, _msgSender(), reward, twabMetadata.rewardedAt, amount);
  }

  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyRewardManager($);

    IERC20(reward).transferFrom(msg.sender, address(this), amount);

    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    _assertValidRewardMetadata(twabMetadata);

    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);

    RewardInfo storage rewardInfo = assetRewards.rewards[twabMetadata.rewardedAt].push();
    rewardInfo.erc20TWABSnapshots = twabMetadata.erc20TWABSnapshots;
    rewardInfo.total = amount;
    rewardInfo.startsAt = twabMetadata.rewardedAt - $.twabPeriod;
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _calculateTotalReward(RewardInfo[] storage rewards, address account, uint48 rewardedAt)
    internal
    view
    returns (uint256 totalReward)
  {
    for (uint256 i = 0; i < rewards.length; i++) {
      RewardInfo storage rewardInfo = rewards[i];
      uint256 rewardAmount = _calculateUserReward(rewardInfo, account, rewardedAt);
      totalReward += rewardAmount;
    }
  }

  function _claimAllReward(AssetRewards storage assetRewards, address sender, address reward, uint48 rewardedAt)
    internal
  {
    Receipt storage receipt = assetRewards.receipts[rewardedAt][sender];
    uint256 totalReward = _calculateTotalReward(assetRewards.rewards[rewardedAt], sender, rewardedAt);
    uint256 claimableReward = totalReward - receipt.claimedAmount;

    if (claimableReward > 0) {
      _updateReceipt(receipt, totalReward, claimableReward);
      IERC20(reward).transfer(sender, claimableReward);
    }
  }

  function _claimPartialReward(
    AssetRewards storage assetRewards,
    address sender,
    address reward,
    uint48 rewardedAt,
    uint256 amount
  ) internal {
    Receipt storage receipt = assetRewards.receipts[rewardedAt][sender];
    uint256 totalReward = _calculateTotalReward(assetRewards.rewards[rewardedAt], sender, rewardedAt);
    uint256 claimableReward = totalReward - receipt.claimedAmount;

    require(claimableReward >= amount, ITWABRewardDistributor__InsufficientReward());

    _updateReceipt(receipt, totalReward, amount);
    IERC20(reward).transfer(sender, amount);
  }

  function _updateReceipt(Receipt storage receipt, uint256 totalReward, uint256 claimedReward) internal {
    receipt.claimedAmount += claimedReward;
    if (receipt.claimedAmount == totalReward) {
      receipt.claimed = true;
    }
  }

  function _calculateUserReward(RewardInfo storage rewardInfo, address account, uint48 rewardedAt)
    internal
    view
    returns (uint256)
  {
    uint48 startsAt = rewardInfo.startsAt;
    uint48 endsAt = rewardedAt;

    uint256 totalTWAB =
      TWABSnapshotsUtils.getTotalTWABByTimestampRange(ITWABSnapshots(rewardInfo.erc20TWABSnapshots), startsAt, endsAt);

    if (totalTWAB == 0) return 0;

    uint256 userTWAB = TWABSnapshotsUtils.getAccountTWABByTimestampRange(
      ITWABSnapshots(rewardInfo.erc20TWABSnapshots), account, startsAt, endsAt
    );

    return (rewardInfo.total * userTWAB) / totalTWAB; // TODO: precision?
  }

  function _assertValidRewardMetadata(RewardTWABMetadata memory metadata) internal view {
    require(metadata.erc20TWABSnapshots != address(0), ITWABRewardDistributor__InvalidERC20TWABSnapshots());
    require(metadata.rewardedAt >= block.timestamp, ITWABRewardDistributor__InvalidRewardedAt());
  }
}
