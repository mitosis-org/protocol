// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibString } from '@solady/utils/LibString.sol';

import { IAssetManager } from '../../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../../interfaces/hub/core/IHubAsset.sol';
import { IOptOutQueueStorageV1 } from '../../../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLVault } from '../../../interfaces/hub/eol/IEOLVault.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../../lib/LibRedeemQueue.sol';
import { StdError } from '../../../lib/StdError.sol';
import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

abstract contract OptOutQueueStorageV1 is IOptOutQueueStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;
  using LibString for address;
  using LibRedeemQueue for LibRedeemQueue.Queue;
  using LibRedeemQueue for LibRedeemQueue.Index;

  struct EOLVaultState {
    // queue
    bool isEnabled;
    LibRedeemQueue.Queue queue;
    // vault
    uint8 decimalsOffset;
    uint8 underlyingDecimals;
  }

  struct StorageV1 {
    IAssetManager assetManager;
    mapping(address eolVault => EOLVaultState state) states;
  }

  string private constant _NAMESPACE = 'mitosis.storage.OptOutQueueStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function assetManager() external view returns (address) {
    return address(_getStorageV1().assetManager);
  }

  function redeemPeriod(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).redeemPeriod;
  }

  function getRequest(address eolVault, uint256[] calldata reqIds)
    external
    view
    returns (IOptOutQueueStorageV1.GetRequestResponse[] memory resp)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, eolVault);

    resp = new IOptOutQueueStorageV1.GetRequestResponse[](reqIds.length);
    for (uint256 i = 0; i < reqIds.length; i++) {
      resp[i].id = reqIds[i];
      resp[i].request = queue.get(reqIds[i]);
    }
    return resp;
  }

  function getRequestByReceiver(address eolVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (IOptOutQueueStorageV1.GetRequestByIndexResponse[] memory resp)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, eolVault);

    resp = new IOptOutQueueStorageV1.GetRequestByIndexResponse[](idxItemIds.length);
    for (uint256 i = 0; i < idxItemIds.length; i++) {
      resp[i].id = idxItemIds[i];
      resp[i].indexId = queue.index(receiver).get(idxItemIds[i]);
      resp[i].request = queue.get(resp[i].indexId);
    }
    return resp;
  }

  function reservedAt(address eolVault, uint256 reqId) external view returns (uint256 reservedAt_, bool isReserved) {
    return _queue(_getStorageV1(), eolVault).reservedAt(reqId);
  }

  function resolvedAt(address eolVault, uint256 reqId) external view returns (uint256 resolvedAt_, bool isResolved) {
    return _queue(_getStorageV1(), eolVault).resolvedAt(reqId, block.timestamp);
  }

  function requestShares(address eolVault, uint256 reqId) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).shares(reqId);
  }

  function requestAssets(address eolVault, uint256 reqId) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).assets(reqId);
  }

  function queueSize(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).size;
  }

  function queueIndexSize(address eolVault, address recipient) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).index(recipient).size;
  }

  function queueOffset(address eolVault, bool simulate) external view returns (uint256 offset) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), eolVault);
    if (simulate) (offset,) = queue.searchQueueOffset(queue.totalReservedAssets);
    else offset = queue.offset;
    return offset;
  }

  function queueIndexOffset(address eolVault, address recipient, bool simulate) external view returns (uint256 offset) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), eolVault);
    if (simulate) (offset,) = queue.searchIndexOffset(recipient, queue.totalReservedAssets);
    else offset = queue.index(recipient).offset;
    return offset;
  }

  function totalReserved(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).totalReservedAssets;
  }

  function totalClaimed(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).totalClaimedAssets;
  }

  function totalPending(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).pending();
  }

  function reserveHistory(address eolVault, uint256 index) external view returns (LibRedeemQueue.ReserveLog memory) {
    return _queue(_getStorageV1(), eolVault).reserveHistory[index];
  }

  function reserveHistoryLength(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).reserveHistory.length;
  }

  function isEnabled(address eolVault) external view returns (bool) {
    return _getStorageV1().states[eolVault].isEnabled;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _enableQueue(StorageV1 storage $, address eolVault) internal {
    $.states[eolVault].isEnabled = true;

    uint8 underlyingDecimals = IHubAsset(IEOLVault(eolVault).asset()).decimals();
    $.states[eolVault].underlyingDecimals = underlyingDecimals;
    $.states[eolVault].decimalsOffset = IEOLVault(eolVault).decimals() - underlyingDecimals;

    emit QueueEnabled(eolVault);
  }

  function _setAssetManager(StorageV1 storage $, address assetManager_) internal {
    if (assetManager_.code.length == 0) revert StdError.InvalidAddress('AssetManager');

    $.assetManager = IAssetManager(assetManager_);

    emit AssetManagerSet(assetManager_);
  }

  function _setRedeemPeriod(StorageV1 storage $, address eolVault, uint256 redeemPeriod_) internal {
    _assertQueueEnabled($, eolVault);

    $.states[eolVault].queue.redeemPeriod = redeemPeriod_;

    emit RedeemPeriodSet(eolVault, redeemPeriod_);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _queue(StorageV1 storage $, address eolVault) private view returns (LibRedeemQueue.Queue storage) {
    return $.states[eolVault].queue;
  }

  // ============================ NOTE: VIRTUAL FUNCTIONS ============================== //

  function _assertOnlyAssetManager(StorageV1 storage $) internal view virtual {
    if (_msgSender() != address($.assetManager)) revert StdError.Unauthorized();
  }

  /// @dev leave this function virtual to intend to use custom errors with overriding.
  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view virtual {
    require(
      $.states[eolVault].isEnabled,
      string.concat('OptOutQueueStorageV1: queue not enabled for eolVault: ', eolVault.toHexString())
    );
  }
}
