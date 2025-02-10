// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { LibString } from '@solady/utils/LibString.sol';

import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { IReclaimQueueStorageV1 } from '../../interfaces/hub/matrix/IReclaimQueue.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract ReclaimQueueStorageV1 is IReclaimQueueStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;
  using SafeCast for uint256;
  using LibString for address;
  using LibRedeemQueue for LibRedeemQueue.Queue;
  using LibRedeemQueue for LibRedeemQueue.Index;

  struct MatrixVaultState {
    // queue
    bool isEnabled;
    LibRedeemQueue.Queue queue;
    // vault
    uint8 decimalsOffset;
    uint8 underlyingDecimals;
  }

  struct StorageV1 {
    IAssetManager assetManager;
    mapping(address matrixVault => MatrixVaultState state) states;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ReclaimQueueStorage.v1';
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

  function redeemPeriod(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).redeemPeriod;
  }

  function getStatus(address matrixVault, uint256 reqId) external view returns (RequestStatus) {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, matrixVault);

    LibRedeemQueue.Request memory req = queue.get(reqId);
    (, bool isResolved) = queue.resolvedAt(reqId, block.timestamp);

    if (req.claimedAt > 0) return RequestStatus.Claimed;
    if (isResolved) return RequestStatus.Claimable;
    if (reqId >= queue.offset) return RequestStatus.Requested;
    return RequestStatus.None;
  }

  function getRequest(address matrixVault, uint256[] calldata reqIds)
    external
    view
    returns (IReclaimQueueStorageV1.GetRequestResponse[] memory)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, matrixVault);

    IReclaimQueueStorageV1.GetRequestResponse[] memory resp =
      new IReclaimQueueStorageV1.GetRequestResponse[](reqIds.length);
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

  function getRequestByReceiver(address matrixVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (IReclaimQueueStorageV1.GetRequestByIndexResponse[] memory)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, matrixVault);

    IReclaimQueueStorageV1.GetRequestByIndexResponse[] memory resp =
      new IReclaimQueueStorageV1.GetRequestByIndexResponse[](idxItemIds.length);
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

  function reservedAt(address matrixVault, uint256 reqId) external view returns (uint256 reservedAt_, bool isReserved) {
    return _queue(_getStorageV1(), matrixVault).reservedAt(reqId);
  }

  function resolvedAt(address matrixVault, uint256 reqId) external view returns (uint256 resolvedAt_, bool isResolved) {
    return _queue(_getStorageV1(), matrixVault).resolvedAt(reqId, block.timestamp);
  }

  function requestShares(address matrixVault, uint256 reqId) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).shares(reqId);
  }

  function requestAssets(address matrixVault, uint256 reqId) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).assets(reqId);
  }

  function queueSize(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).size;
  }

  function queueIndexSize(address matrixVault, address recipient) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).index(recipient).size;
  }

  function queueOffset(address matrixVault, bool simulate) external view returns (uint256) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), matrixVault);
    uint256 offset;
    if (simulate) (offset,) = queue.searchQueueOffset(queue.totalReservedAssets, block.timestamp);
    else offset = queue.offset;
    return offset;
  }

  function queueIndexOffset(address matrixVault, address recipient, bool simulate) external view returns (uint256) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), matrixVault);
    uint256 offset;
    if (simulate) (offset,) = queue.searchIndexOffset(recipient, queue.totalReservedAssets, block.timestamp);
    else offset = queue.index(recipient).offset;
    return offset;
  }

  function totalReserved(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).totalReservedAssets;
  }

  function totalClaimed(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).totalClaimedAssets;
  }

  function totalPending(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).pending();
  }

  function reserveHistory(address matrixVault, uint256 index) external view returns (GetReserveHistoryResponse memory) {
    LibRedeemQueue.ReserveLog memory log = _queue(_getStorageV1(), matrixVault).reserveHistory[index];
    return GetReserveHistoryResponse({
      accumulatedShares: log.accumulatedShares,
      accumulatedAssets: log.accumulatedAssets,
      reservedAt: log.reservedAt,
      totalShares: log.totalShares,
      totalAssets: log.totalAssets
    });
  }

  function reserveHistoryLength(address matrixVault) external view returns (uint256) {
    return _queue(_getStorageV1(), matrixVault).reserveHistory.length;
  }

  function isEnabled(address matrixVault) external view returns (bool) {
    return _getStorageV1().states[matrixVault].isEnabled;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _enableQueue(StorageV1 storage $, address matrixVault) internal {
    $.states[matrixVault].isEnabled = true;

    uint8 underlyingDecimals = IHubAsset(IMatrixVault(matrixVault).asset()).decimals();
    $.states[matrixVault].underlyingDecimals = underlyingDecimals;
    $.states[matrixVault].decimalsOffset = IMatrixVault(matrixVault).decimals() - underlyingDecimals;

    emit QueueEnabled(matrixVault);
  }

  function _setAssetManager(StorageV1 storage $, address assetManager_) internal {
    require(assetManager_.code.length > 0, StdError.InvalidAddress('AssetManager'));

    $.assetManager = IAssetManager(assetManager_);

    emit AssetManagerSet(assetManager_);
  }

  function _setRedeemPeriod(StorageV1 storage $, address matrixVault, uint256 redeemPeriod_) internal {
    _assertQueueEnabled($, matrixVault);

    $.states[matrixVault].queue.redeemPeriod = redeemPeriod_;

    emit RedeemPeriodSet(matrixVault, redeemPeriod_);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _queue(StorageV1 storage $, address matrixVault) private view returns (LibRedeemQueue.Queue storage) {
    return $.states[matrixVault].queue;
  }

  // ============================ NOTE: VIRTUAL FUNCTIONS ============================== //

  function _assertOnlyAssetManager(StorageV1 storage $) internal view virtual {
    require(_msgSender() == address($.assetManager), StdError.Unauthorized());
  }

  /// @dev leave this function virtual to intend to use custom errors with overriding.
  function _assertQueueEnabled(StorageV1 storage $, address matrixVault) internal view virtual {
    require(
      $.states[matrixVault].isEnabled,
      string.concat('ReclaimQueueStorageV1: queue not enabled for matrixVault: ', matrixVault.toHexString())
    );
  }
}
