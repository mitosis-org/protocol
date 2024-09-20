// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IRewardConfigurator } from '../../interfaces/hub/reward/IRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ITWABRewardDistributorStorageV1 } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract TWABRewardDistributorStorageV1 is ITWABRewardDistributorStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct Receipt {
    bool claimed;
    uint256 claimedAmount;
  }

  struct AssetRewards {
    uint48 lastBatchTimestamp;
    uint48[] batchTimestamps;
    mapping(uint48 batchTimestamp => uint256 total) batchRewards;
    mapping(uint48 batchTimestamp => mapping(address account => Receipt receipt)) receipts;
  }

  struct StorageV1 {
    DistributionType distributionType;
    address rewardConfigurator;
    address rewardManager;
    string description;
    uint48 twabPeriod;
    mapping(address twabCriteria => mapping(address reward => AssetRewards assetRewards)) rewards;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TWABRewardDistributorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function distributionType() external view returns (DistributionType) {
    return _getStorageV1().distributionType;
  }

  function description() external view returns (string memory) {
    return _getStorageV1().description;
  }

  function rewardConfigurator() external view returns (address) {
    return _getStorageV1().rewardConfigurator;
  }

  function rewardManager() external view returns (address) {
    return _getStorageV1().rewardManager;
  }

  function twabPeriod() external view returns (uint48) {
    return _getStorageV1().twabPeriod;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setRewardConfigurator(StorageV1 storage $, address rewardConfigurator_) internal {
    $.rewardConfigurator = rewardConfigurator_;
    emit RewardConfiguratorSet(rewardConfigurator_);
  }

  function _setRewardManager(StorageV1 storage $, address rewardManager_) internal {
    $.rewardManager = rewardManager_;
    emit RewardManagerSet(rewardManager_);
  }

  function _setTWABPeriod(StorageV1 storage $, uint48 period) internal {
    require(period > 0, ITWABRewardDistributorStorageV1__ZeroPeriod());
    $.twabPeriod = period;
    emit TWABPeriodSet(period);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _assetRewards(address twabCriteria, address reward) internal view returns (AssetRewards storage) {
    return _getStorageV1().rewards[twabCriteria][reward];
  }

  function _assetRewards(StorageV1 storage $, address twabCriteria, address reward)
    internal
    view
    returns (AssetRewards storage)
  {
    return $.rewards[twabCriteria][reward];
  }

  function _receipt(address account, address twabCriteria, address reward, uint48 rewardedAt)
    internal
    view
    returns (Receipt storage)
  {
    return _getStorageV1().rewards[twabCriteria][reward].receipts[rewardedAt][account];
  }

  function _receipt(StorageV1 storage $, address account, address twabCriteria, address reward, uint48 rewardedAt)
    internal
    view
    returns (Receipt storage)
  {
    return $.rewards[twabCriteria][reward].receipts[rewardedAt][account];
  }

  function _batchRewards(address twabCriteria, address reward, uint48 rewardedAt) internal view returns (uint256) {
    return _getStorageV1().rewards[twabCriteria][reward].batchRewards[rewardedAt];
  }

  function _batchRewards(StorageV1 storage $, address twabCriteria, address reward, uint48 rewardedAt)
    internal
    view
    returns (uint256)
  {
    return $.rewards[twabCriteria][reward].batchRewards[rewardedAt];
  }

  function _assertOnlyRewardManager(StorageV1 storage $) internal view {
    require($.rewardManager == _msgSender(), StdError.Unauthorized());
  }

  function _assertOnlyRewardConfigurator(StorageV1 storage $) internal view {
    require(address($.rewardConfigurator) == _msgSender(), StdError.Unauthorized());
  }
}
