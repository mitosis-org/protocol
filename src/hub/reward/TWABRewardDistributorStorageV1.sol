// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IRedistributionRegistry } from '../../interfaces/hub/core/IRedistributionRegistry.sol';
import { ITWABRewardDistributorStorageV1 } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract TWABRewardDistributorStorageV1 is ITWABRewardDistributorStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct AssetRewards {
    uint48 firstBatchTimestamp;
    mapping(uint48 batchTimestamp => uint256 total) batchRewards;
    mapping(address account => uint48 lastClaimedBatchTimestamp) lastClaimedBatchTimestamps;
  }

  struct StorageV1 {
    uint48 batchPeriod;
    uint48 twabPeriod;
    uint256 rewardPrecision;
    mapping(address eolVault => mapping(address reward => AssetRewards assetRewards)) rewards;
    IRedistributionRegistry redistributionRegistry;
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

  function batchPeriod() external view returns (uint48) {
    return _getStorageV1().batchPeriod;
  }

  function twabPeriod() external view returns (uint48) {
    return _getStorageV1().twabPeriod;
  }

  function rewardPrecision() external view returns (uint256) {
    return _getStorageV1().rewardPrecision;
  }

  function redistributionRegistry() external view returns (IRedistributionRegistry) {
    return _getStorageV1().redistributionRegistry;
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

  function _setBatchPeriodUnsafe(StorageV1 storage $, uint48 period) internal {
    $.batchPeriod = period;
    emit BatchPeriodSetUnsafe(period);
  }

  function _setRedistributionRegistry(StorageV1 storage $, IRedistributionRegistry registry) internal {
    $.redistributionRegistry = registry;
    emit RedistributionRegistrySet(address(registry));
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _assetRewards(StorageV1 storage $, address eolVault, address reward)
    internal
    view
    returns (AssetRewards storage)
  {
    return $.rewards[eolVault][reward];
  }

  function _batchRewards(StorageV1 storage $, address eolVault, address reward, uint48 batchTimestamp)
    internal
    view
    returns (uint256)
  {
    return $.rewards[eolVault][reward].batchRewards[batchTimestamp];
  }
}
