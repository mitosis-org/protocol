// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVaultStorageV1 } from '../../interfaces/hub/eol/IEOLVault.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLVaultStorageV1 is IEOLVaultStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct StorageV1 {
    IEOLRewardManager rewardManager;
    IAssetManager assetManager;
    uint256 totalAssets;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLVaultStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function rewardManager() external view returns (address) {
    return address(_getStorageV1().rewardManager);
  }

  function assetManager() external view returns (address) {
    return address(_getStorageV1().assetManager);
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setRewardManager(StorageV1 storage $, address rewardManager_) internal {
    require(rewardManager_.code.length > 0, StdError.InvalidAddress('RewardManager'));

    $.rewardManager = IEOLRewardManager(rewardManager_);

    emit RewardManagerSet(rewardManager_);
  }

  function _setAssetManager(StorageV1 storage $, address assetManager_) internal {
    require(assetManager_.code.length > 0, StdError.InvalidAddress('AssetManager'));

    $.assetManager = IAssetManager(assetManager_);

    emit AssetManagerSet(assetManager_);
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _assertOnlyOptOutQueue(StorageV1 storage $) internal view {
    require(_msgSender() == $.assetManager.optOutQueue(), StdError.Unauthorized());
  }
}
