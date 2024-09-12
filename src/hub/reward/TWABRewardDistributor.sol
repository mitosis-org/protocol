// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { DistributionType } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IRewardConfigurator } from '../../interfaces/hub/reward/IRewardConfigurator.sol';
import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';
import { LibDistributorRewardMetadata, RewardTWABMetadata } from './LibDistributorRewardMetadata.sol';
import { TWABRewardDistributorStorageV1 } from './TWABRewardDistributorStorageV1.sol';

contract TWABRewardDistributor is ITWABRewardDistributor, Ownable2StepUpgradeable, TWABRewardDistributorStorageV1 {
  using LibDistributorRewardMetadata for RewardTWABMetadata;
  using LibDistributorRewardMetadata for bytes;
  using TWABSnapshotsUtils for ITWABSnapshots;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address rewardManager_, address rewardConfigurator_, uint48 twabPeriod_)
    public
    initializer
  {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();
    _setRewardManager($, rewardManager_);
    _setRewardConfigurator($, rewardConfigurator_);
    _setTWABPeriod($, twabPeriod_);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function encodeMetadata(address twabCriteria, uint48 rewardedAt) external pure returns (bytes memory) {
    return RewardTWABMetadata({ twabCriteria: twabCriteria, rewardedAt: rewardedAt }).encode();
  }

  function claimable(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (bool)
  {
    return claimableAmount(account, eolVault, asset, metadata) > 0;
  }

  function claimableAmount(address account, address eolVault, address asset, bytes calldata metadata)
    public
    view
    returns (uint256)
  {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    uint48 rewardedAt = twabMetadata.rewardedAt;

    StorageV1 storage $ = _getStorageV1();

    RewardInfo[] storage rewards = _rewardInfos($, eolVault, asset, rewardedAt);
    Receipt storage receipt = _receipt($, account, eolVault, asset, rewardedAt);

    if (receipt.claimed) return 0;

    uint256 totalReawrd = _calculateTotalReward(rewards, account, rewardedAt);
    return totalReawrd - receipt.claimedAmount;
  }

  function rewardedAts(address eolVault, address asset, uint256 startIndex, uint256 endIndex)
    external
    view
    returns (uint48[] memory result)
  {
    AssetRewards storage assetRewards = _assetRewards(eolVault, asset);

    result = new uint48[](endIndex - startIndex);
    for (uint256 i = startIndex; i < endIndex; i++) {
      result[i - startIndex] = assetRewards.rewardedAts[i];
    }
  }

  function rewardedAtsLength(address eolVault, address asset) external view returns (uint256) {
    return _assetRewards(eolVault, asset).rewardedAts.length;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function setRewardManager(address rewardManager_) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyRewardConfigurator($);

    _setRewardManager($, rewardManager_);
  }

  function setRewardConfigurator(address rewardConfigurator_) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyRewardConfigurator($);

    _setRewardConfigurator($, rewardConfigurator_);
  }

  function setTWABPeriod(uint48 period) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyRewardConfigurator($);

    _setTWABPeriod($, period);
  }

  function claim(address eolVault, address reward, bytes calldata metadata) external {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimAllReward(_msgSender(), eolVault, reward, twabMetadata.rewardedAt);
  }

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimPartialReward(_msgSender(), eolVault, reward, twabMetadata.rewardedAt, amount);
  }

  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyRewardManager($);

    IERC20(reward).transferFrom(_msgSender(), address(this), amount);

    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    _assertValidRewardMetadata(twabMetadata);

    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);
    RewardInfo[] storage rewards = assetRewards.rewards[twabMetadata.rewardedAt];

    if (rewards.length == 0) {
      assetRewards.rewardedAts.push(twabMetadata.rewardedAt);
    }

    rewards.push(
      RewardInfo({ twabCriteria: ITWABSnapshots(twabMetadata.twabCriteria), total: amount, twabPeriod: $.twabPeriod })
    );
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

  function _claimAllReward(address account, address eolVault, address reward, uint48 rewardedAt) internal {
    AssetRewards storage assetRewards = _assetRewards(eolVault, reward);
    Receipt storage receipt = assetRewards.receipts[rewardedAt][account];

    uint256 totalReward = _calculateTotalReward(assetRewards.rewards[rewardedAt], account, rewardedAt);
    uint256 claimableReward = totalReward - receipt.claimedAmount;

    if (claimableReward > 0) {
      _updateReceipt(receipt, totalReward, claimableReward);
      IERC20(reward).transfer(account, claimableReward);
    }
  }

  function _claimPartialReward(address account, address eolVault, address reward, uint48 rewardedAt, uint256 amount)
    internal
  {
    AssetRewards storage assetRewards = _assetRewards(eolVault, reward);
    Receipt storage receipt = assetRewards.receipts[rewardedAt][account];

    uint256 totalReward = _calculateTotalReward(assetRewards.rewards[rewardedAt], account, rewardedAt);
    uint256 claimableReward = totalReward - receipt.claimedAmount;

    require(claimableReward >= amount, ITWABRewardDistributor__InsufficientReward());

    _updateReceipt(receipt, totalReward, amount);
    IERC20(reward).transfer(account, amount);
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
    uint48 twabPeriod = rewardInfo.twabPeriod;
    uint48 startsAt;
    startsAt = twabPeriod > rewardedAt ? 0 : rewardedAt - twabPeriod;

    uint48 endsAt = rewardedAt;

    ITWABSnapshots criteria = rewardInfo.twabCriteria;

    uint256 totalTWAB = criteria.getTotalTWABByTimestampRange(startsAt, endsAt);
    if (totalTWAB == 0) return 0;

    uint256 userTWAB = criteria.getAccountTWABByTimestampRange(account, startsAt, endsAt);
    if (userTWAB == 0) return 0;

    uint256 precision = IRewardConfigurator(_getStorageV1().rewardConfigurator).rewardRatioPrecision();

    uint256 userRatio = Math.mulDiv(userTWAB, precision, totalTWAB);
    if (userRatio == 0) return 0;

    return Math.mulDiv(rewardInfo.total, userRatio, precision);
  }

  function _assertValidRewardMetadata(RewardTWABMetadata memory metadata) internal view {
    require(metadata.twabCriteria != address(0), ITWABRewardDistributor__InvalidTWABCriteria());
    require(metadata.rewardedAt >= block.timestamp, ITWABRewardDistributor__InvalidRewardedAt());
  }
}
