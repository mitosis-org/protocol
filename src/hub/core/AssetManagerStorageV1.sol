// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManagerStorageV1 } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IOptOutQueue } from '../../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract AssetManagerStorageV1 is IAssetManagerStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  error AssetManagerStorageV1__BranchAssetPairNotExist(address branchAsset);
  error AssetManagerStorageV1__EOLRewardManagerNotSet();

  error AssetManagerStorageV1__EOLNotInitialized(uint256 chainId, address eolVault);
  error AssetManagerStorageV1__EOLAlreadyInitialized(uint256 chainId, address eolVault);

  struct EOLState {
    address strategist;
    uint256 allocation;
  }

  struct StorageV1 {
    IAssetManagerEntrypoint entrypoint;
    IOptOutQueue optOutQueue;
    IEOLRewardManager rewardManager;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => address branchAsset)) branchAssets;
    mapping(uint256 chainId => mapping(address branchAsset => address hubAsset)) hubAssets;
    mapping(uint256 chainId => mapping(address hubAsset => uint256 amount)) collateralPerChain;
    // EOL states
    mapping(address eolVault => EOLState state) eolStates;
    mapping(uint256 chainId => mapping(address eolVault => bool initialized)) eolInitialized;
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

  function rewardManager() external view returns (address) {
    return address(_getStorageV1().rewardManager);
  }

  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address) {
    return _getStorageV1().branchAssets[hubAsset_][chainId];
  }

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address) {
    return _getStorageV1().hubAssets[chainId][branchAsset_];
  }

  function collateral(uint256 chainId, address hubAsset_) external view returns (uint256) {
    return _getStorageV1().collateralPerChain[chainId][hubAsset_];
  }

  function eolInitialized(uint256 chainId, address eolVault) external view returns (bool) {
    return _getStorageV1().eolInitialized[chainId][eolVault];
  }

  function eolIdle(address eolVault) external view returns (uint256) {
    return _eolIdle(_getStorageV1(), eolVault);
  }

  function eolAlloc(address eolVault) external view returns (uint256) {
    return _getStorageV1().eolStates[eolVault].allocation;
  }

  function stategist(address eolVault) external view returns (address) {
    return _getStorageV1().eolStates[eolVault].strategist;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setEntrypoint(StorageV1 storage $, address entrypoint_) internal {
    require(entrypoint_.code.length > 0, StdError.InvalidAddress('Entrypoint'));

    $.entrypoint = IAssetManagerEntrypoint(entrypoint_);

    emit EntrypointSet(entrypoint_);
  }

  function _setOptOutQueue(StorageV1 storage $, address optOutQueue_) internal {
    require(optOutQueue_.code.length > 0, StdError.InvalidAddress('OptOutQueue'));

    $.optOutQueue = IOptOutQueue(optOutQueue_);

    emit OptOutQueueSet(optOutQueue_);
  }

  function _setRewardManager(StorageV1 storage $, address rewardManager_) internal {
    require(rewardManager_.code.length > 0, StdError.InvalidAddress('EOLRewardManager'));

    $.rewardManager = IEOLRewardManager(rewardManager_);

    emit RewardManagerSet(rewardManager_);
  }

  function _setStrategist(StorageV1 storage $, address eolVault, address strategist) internal {
    $.eolStates[eolVault].strategist = strategist;

    emit StrategistSet(eolVault, strategist);
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
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }

  function _assertOnlyStrategist(StorageV1 storage $, address eolVault) internal view virtual {
    require(_msgSender() == $.eolStates[eolVault].strategist, StdError.Unauthorized());
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    virtual
  {
    require(
      $.hubAssets[chainId][branchAsset_] != address(0), AssetManagerStorageV1__BranchAssetPairNotExist(branchAsset_)
    );
  }

  function _assertEOLRewardManagerSet(StorageV1 storage $) internal view virtual {
    require(address($.rewardManager) != address(0), AssetManagerStorageV1__EOLRewardManagerNotSet());
  }

  function _assertEOLInitialized(StorageV1 storage $, uint256 chainId, address eolVault) internal view virtual {
    require($.eolInitialized[chainId][eolVault], AssetManagerStorageV1__EOLNotInitialized(chainId, eolVault));
  }

  function _assertEOLNotInitialized(StorageV1 storage $, uint256 chainId, address eolVault) internal view virtual {
    require(!$.eolInitialized[chainId][eolVault], AssetManagerStorageV1__EOLAlreadyInitialized(chainId, eolVault));
  }
}
