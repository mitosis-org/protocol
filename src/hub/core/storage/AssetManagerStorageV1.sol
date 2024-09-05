// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManagerStorageV1 } from '../../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { IOptOutQueue } from '../../../interfaces/hub/core/IOptOutQueue.sol';
import { IRewardTreasury } from '../../../interfaces/hub/core/IRewardTreasury.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { StdError } from '../../../lib/StdError.sol';

abstract contract AssetManagerStorageV1 is IAssetManagerStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct EOLStates {
    address strategist;
    uint256 allocation;
  }

  struct StorageV1 {
    IAssetManagerEntrypoint entrypoint;
    IOptOutQueue optOutQueue;
    IRewardTreasury rewardTreasury;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => address branchAsset)) branchAssets;
    mapping(uint256 chainId => mapping(address branchAsset => address hubAsset)) hubAssets;
    // EOL states
    mapping(address eolVault => EOLStates state) eolStates;
  }

  string private constant _NAMESPACE = 'mitosis.storage.AssetManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function optOutQueue() external view returns (address) {
    return address(_getStorageV1().optOutQueue);
  }

  function rewardTreasury() external view returns (address) {
    return address(_getStorageV1().rewardTreasury);
  }

  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address) {
    return _getStorageV1().branchAssets[hubAsset_][chainId];
  }

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address) {
    return _getStorageV1().hubAssets[chainId][branchAsset_];
  }

  function eolIdle(address eolVault) external view returns (uint256) {
    return _eolIdle(_getStorageV1(), eolVault);
  }

  function eolAlloc(address eolVault) external view returns (uint256) {
    return _getStorageV1().eolStates[eolVault].allocation;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setEntrypoint(StorageV1 storage $, address entrypoint_) internal {
    if (entrypoint_.code.length == 0) revert StdError.InvalidAddress('Entrypoint');

    $.entrypoint = IAssetManagerEntrypoint(entrypoint_);

    emit EntrypointSet(entrypoint_);
  }

  function _setOptOutQueue(StorageV1 storage $, address optOutQueue_) internal {
    if (optOutQueue_.code.length == 0) revert StdError.InvalidAddress('OptOutQueue');

    $.optOutQueue = IOptOutQueue(optOutQueue_);

    emit OptOutQueueSet(optOutQueue_);
  }

  function _setRewardTreasury(StorageV1 storage $, address rewardTreasury_) internal {
    if (rewardTreasury_.code.length == 0) revert StdError.InvalidAddress('RewardTreasury');

    $.rewardTreasury = IRewardTreasury(rewardTreasury_);

    emit RewardTreasurySet(rewardTreasury_);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _eolIdle(StorageV1 storage $, address eolVault) internal view returns (uint256) {
    uint256 total = IEOLVault(eolVault).totalAssets();
    uint256 pending = $.optOutQueue.totalPending(eolVault);
    uint256 allocated = $.eolStates[eolVault].allocation;

    return total - pending - allocated;
  }

  // ============================ NOTE: VIRTUAL FUNCTIONS ============================ //

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view virtual {
    if (_msgSender() != address($.entrypoint)) revert StdError.Unauthorized();
  }

  function _assertOnlyStrategist(StorageV1 storage $, address eolVault) internal view virtual {
    if (_msgSender() != $.eolStates[eolVault].strategist) revert StdError.Unauthorized();
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    virtual
  {
    require($.hubAssets[chainId][branchAsset_] != address(0), 'AssetManagerStorageV1: branch asset pair not exists');
  }

  function _assertRewardTreasurySet(StorageV1 storage $) internal view virtual {
    require(address($.rewardTreasury) != address(0), 'AssetManagerStorageV1: reward treasury not set');
  }
}
