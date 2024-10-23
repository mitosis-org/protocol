// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

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
    uint48 twabPeriod;
    uint256 rewardPrecision;
    mapping(address eolVault => mapping(address reward => AssetRewards assetRewards)) rewards;
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

  function twabPeriod() external view returns (uint48) {
    return _getStorageV1().twabPeriod;
  }

  function rewardPrecision() external view returns (uint256) {
    return _getStorageV1().rewardPrecision;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setTWABPeriod(StorageV1 storage $, uint48 period) internal {
    require(period > 0, ITWABRewardDistributorStorageV1__ZeroPeriod());
    $.twabPeriod = period;
    emit TWABPeriodSet(period);
  }

  function _setRewardPrecision(StorageV1 storage $, uint256 precision) internal {
    require(precision > 0, StdError.InvalidParameter('precision'));
    $.rewardPrecision = precision;
    emit RewardPrecisionSet(precision);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _assetRewards(address eolVault, address reward) internal view returns (AssetRewards storage) {
    return _getStorageV1().rewards[eolVault][reward];
  }

  function _assetRewards(StorageV1 storage $, address eolVault, address reward)
    internal
    view
    returns (AssetRewards storage)
  {
    return $.rewards[eolVault][reward];
  }

  function _receipt(address account, address eolVault, address reward, uint48 batchTimestamp)
    internal
    view
    returns (Receipt storage)
  {
    return _getStorageV1().rewards[eolVault][reward].receipts[batchTimestamp][account];
  }

  function _receipt(StorageV1 storage $, address account, address eolVault, address reward, uint48 batchTimestamp)
    internal
    view
    returns (Receipt storage)
  {
    return $.rewards[eolVault][reward].receipts[batchTimestamp][account];
  }

  function _batchRewards(address eolVault, address reward, uint48 batchTimestamp) internal view returns (uint256) {
    return _getStorageV1().rewards[eolVault][reward].batchRewards[batchTimestamp];
  }

  function _batchRewards(StorageV1 storage $, address eolVault, address reward, uint48 batchTimestamp)
    internal
    view
    returns (uint256)
  {
    return $.rewards[eolVault][reward].batchRewards[batchTimestamp];
  }
}
