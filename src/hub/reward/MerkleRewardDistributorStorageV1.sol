// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IMerkleRewardDistributorStorageV1 } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { IRewardConfigurator } from '../../interfaces/hub/reward/IRewardConfigurator.sol';
import {
  IRewardDistributor,
  IRewardDistributorStorage,
  DistributionType
} from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract MerkleRewardDistributorStorageV1 is IMerkleRewardDistributorStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct Stage {
    uint256 amount;
    bytes32 root;
    mapping(address => bool) claimed;
  }

  struct StorageV1 {
    DistributionType distributionType;
    address rewardConfigurator;
    address rewardManager;
    string description;
    mapping(address eolVault => mapping(address reward => mapping(uint256 stage => Stage))) stages;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MerkleRewardDistributor.v1';
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

  function stage(address eolVault, address reward, uint256 stage_) external view returns (StageResponse memory) {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, eolVault, reward, stage_);
    return StageResponse({ amount: s.amount, root: s.root });
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

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _stage(StorageV1 storage $, address eolVault, address reward, uint256 stage_)
    internal
    view
    returns (Stage storage)
  {
    return $.stages[eolVault][reward][stage_];
  }

  function _assertOnlyRewardManager(StorageV1 storage $) internal view {
    require($.rewardManager == _msgSender(), StdError.Unauthorized());
  }

  function _assertOnlyRewardConfigurator(StorageV1 storage $) internal view {
    require(address($.rewardConfigurator) == _msgSender(), StdError.Unauthorized());
  }
}
