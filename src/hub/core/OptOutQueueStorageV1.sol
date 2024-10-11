// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { LibString } from '@solady/utils/LibString.sol';

import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IOptOutQueueStorageV1 } from '../../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract OptOutQueueStorageV1 is IOptOutQueueStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;
  using SafeCast for uint256;
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

  function getStatus(address eolVault, uint256 reqId) external view returns (RequestStatus status) {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, eolVault);

    LibRedeemQueue.Request memory req = queue.get(reqId);
    (, bool isResolved) = queue.resolvedAt(reqId, block.timestamp);

    if (req.claimedAt > 0) return RequestStatus.Claimed;
    if (isResolved) return RequestStatus.Claimable;
    if (reqId == queue.offset) return RequestStatus.Requested;
    return RequestStatus.None;
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
      LibRedeemQueue.Request memory req = queue.get(reqIds[i]);

      resp[i] = GetRequestResponse({
        id: reqIds[i],
        requestedShares: reqIds[i] > 0
          ? req.accumulatedShares - queue.get(reqIds[i] - 1).accumulatedShares
          : req.accumulatedShares,
        requestedAssets: reqIds[i] > 0
          ? req.accumulatedAssets - queue.get(reqIds[i] - 1).accumulatedAssets
          : req.accumulatedAssets,
        accumulatedShares: req.accumulatedShares,
        accumulatedAssets: req.accumulatedAssets,
        recipient: req.recipient,
        createdAt: req.createdAt,
        claimedAt: req.claimedAt
      });
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
      uint256 indexId = queue.index(receiver).get(idxItemIds[i]);
      LibRedeemQueue.Request memory req = queue.get(indexId);

      resp[i] = GetRequestByIndexResponse({
        id: idxItemIds[i],
        indexId: indexId,
        requestedShares: indexId > 0
          ? req.accumulatedShares - queue.get(indexId - 1).accumulatedShares
          : req.accumulatedShares,
        requestedAssets: indexId > 0
          ? req.accumulatedAssets - queue.get(indexId - 1).accumulatedAssets
          : req.accumulatedAssets,
        accumulatedShares: req.accumulatedShares,
        accumulatedAssets: req.accumulatedAssets,
        recipient: req.recipient,
        createdAt: req.createdAt,
        claimedAt: req.claimedAt
      });
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
    if (simulate) (offset,) = queue.searchQueueOffset(queue.totalReservedAssets, block.timestamp);
    else offset = queue.offset;
    return offset;
  }

  function queueIndexOffset(address eolVault, address recipient, bool simulate) external view returns (uint256 offset) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), eolVault);
    if (simulate) (offset,) = queue.searchIndexOffset(recipient, queue.totalReservedAssets, block.timestamp);
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

  function reserveHistory(address eolVault, uint256 index) external view returns (GetReserveHistoryResponse memory) {
    LibRedeemQueue.ReserveLog memory log = _queue(_getStorageV1(), eolVault).reserveHistory[index];
    return GetReserveHistoryResponse({
      accumulated: log.accumulated,
      reservedAt: log.reservedAt,
      totalShares: log.totalShares,
      totalAssets: log.totalAssets
    });
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
    require(assetManager_.code.length > 0, StdError.InvalidAddress('AssetManager'));

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
    require(_msgSender() == address($.assetManager), StdError.Unauthorized());
  }

  /// @dev leave this function virtual to intend to use custom errors with overriding.
  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view virtual {
    require(
      $.states[eolVault].isEnabled,
      string.concat('OptOutQueueStorageV1: queue not enabled for eolVault: ', eolVault.toHexString())
    );
  }
}
