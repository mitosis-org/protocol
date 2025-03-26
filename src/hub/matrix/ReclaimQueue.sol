// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { ReentrancyGuardTransient } from '@oz-v5/utils/ReentrancyGuardTransient.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { IReclaimQueue } from '../../interfaces/hub/matrix/IReclaimQueue.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { ReclaimQueueStorageV1 } from './ReclaimQueueStorageV1.sol';

contract ReclaimQueue is
  IReclaimQueue,
  Pausable,
  Ownable2StepUpgradeable,
  UUPSUpgradeable,
  ReclaimQueueStorageV1,
  ReentrancyGuardTransient
{
  using SafeERC20 for IMatrixVault;
  using SafeERC20 for IHubAsset;
  using SafeCast for uint256;
  using Math for uint256;
  using LibRedeemQueue for *;

  struct SyncState {
    uint256 queueOffset;
    uint256 queueSize;
    uint256 totalReservedShares;
    uint256 totalReservedAssets;
    uint256 totalShares;
    uint256 totalAssets;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address assetManager) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();

    StorageV1 storage $ = _getStorageV1();
    _setAssetManager($, assetManager);
  }

  // =========================== NOTE: QUERY FUNCTIONS =========================== //

  function previewSync(address matrixVault, uint256 claimCount) external view returns (uint256, uint256) {
    SyncState memory state = _calcSync(_getStorageV1(), IMatrixVault(matrixVault), claimCount);
    return (state.totalReservedShares, state.totalReservedAssets);
  }

  // =========================== NOTE: QUEUE FUNCTIONS =========================== //

  function request(uint256 shares, address receiver, address matrixVault) external whenNotPaused returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, matrixVault);

    IMatrixVault(matrixVault).safeTransferFrom(_msgSender(), address(this), shares);

    // We're subtracting 1 because of the rounding error
    // If there's a better way to handle this, we can apply it
    uint256 assets = IMatrixVault(matrixVault).previewRedeem(shares) - 1;

    uint256 reqId = $.states[matrixVault].queue.enqueue(
      receiver,
      shares,
      block.timestamp.toUint48(),
      /// METADATA
      _encodeRequestMetadata(assets)
    );

    emit ReclaimRequested(receiver, matrixVault, shares, assets);

    return reqId;
  }

  function claim(address receiver, address matrixVault) external nonReentrant whenNotPaused returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, matrixVault);

    LibRedeemQueue.Queue storage queue = $.states[matrixVault].queue;
    LibRedeemQueue.Index storage index = queue.index(receiver);

    uint48 timestamp = block.timestamp.toUint48();

    queue.update(timestamp);

    ClaimConfig memory cfg = ClaimConfig({
      timestamp: timestamp,
      receiver: receiver,
      matrixVault: IMatrixVault(matrixVault),
      hubAsset: IHubAsset(IMatrixVault(matrixVault).asset()),
      decimalsOffset: $.states[matrixVault].decimalsOffset,
      queueOffset: queue.offset,
      idxOffset: index.offset
    });

    // run actual claim logic
    uint256 totalClaimed_ = _claim(queue, index, cfg);
    require(totalClaimed_ > 0, IReclaimQueue__NothingToClaim());

    emit ReclaimRequestClaimed(receiver, matrixVault, totalClaimed_);

    // send total claim amount to receiver
    cfg.hubAsset.safeTransfer(receiver, totalClaimed_);

    return totalClaimed_;
  }

  function sync(address executor, address matrixVault, uint256 claimCount)
    external
    whenNotPaused
    returns (uint256, uint256)
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyAssetManager($);
    _assertQueueEnabled($, matrixVault);

    SyncState memory state = _sync($, executor, IMatrixVault(matrixVault), claimCount);

    return (state.totalReservedShares, state.totalReservedAssets);
  }

  // =========================== NOTE: OWNABLE FUNCTIONS =========================== //

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizePause(address) internal view override onlyOwner { }

  function enable(address matrixVault) external onlyOwner {
    _enableQueue(_getStorageV1(), matrixVault);
  }

  function setAssetManager(address assetManager) external onlyOwner {
    _setAssetManager(_getStorageV1(), assetManager);
  }

  function setRedeemPeriod(address matrixVault, uint256 redeemPeriod_) external onlyOwner {
    _setRedeemPeriod(_getStorageV1(), matrixVault, redeemPeriod_);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  function _abssub(uint256 x, uint256 y) private pure returns (uint256, bool) {
    return (x > y ? x - y : y - x, x > y);
  }

  function _convertToAssets(
    uint256 shares,
    uint8 decimalsOffset,
    uint256 totalAssets,
    uint256 totalSupply,
    Math.Rounding rounding
  ) private pure returns (uint256) {
    return shares.mulDiv(totalAssets + 1, totalSupply + 10 ** decimalsOffset, rounding);
  }

  function _idle(LibRedeemQueue.Queue storage queue, IAssetManager assetManager, address matrixVault)
    internal
    view
    returns (uint256)
  {
    return IMatrixVault(matrixVault).totalAssets() - queue.totalPendingAmount() - assetManager.matrixAlloc(matrixVault);
  }

  function _claim(LibRedeemQueue.Queue storage queue, LibRedeemQueue.Index storage index, ClaimConfig memory cfg)
    internal
    returns (uint256 totalClaimed_)
  {
    uint256 i = cfg.idxOffset;

    for (; i < index.size; i++) {
      if (i - cfg.idxOffset >= LibRedeemQueue.DEFAULT_CLAIM_SIZE) break;

      uint256 reqId = index.data[i];

      LibRedeemQueue.Request memory req = queue.data[reqId];
      if (req.isClaimed()) continue;
      if (reqId >= cfg.queueOffset) break;

      uint256 assetsOnRequest = _decodeRequestMetadata(req.metadata);
      uint256 assetsOnReserve;

      {
        (LibRedeemQueue.ReserveLog memory reserveLog,) = queue.reserveLog(reqId); // found can be ignored

        (uint256 totalShares, uint256 totalAssets) = _decodeReserveMetadata(reserveLog.metadata);

        assetsOnReserve = _convertToAssets(
          reqId == 0 ? req.accumulated : req.accumulated - queue.data[reqId - 1].accumulated,
          cfg.decimalsOffset,
          totalAssets,
          totalShares,
          Math.Rounding.Floor
        );
      }

      queue.data[reqId].claimedAt = cfg.timestamp.toUint48();

      totalClaimed_ += Math.min(assetsOnRequest, assetsOnReserve);

      emit LibRedeemQueue.Claimed(cfg.receiver, reqId);
    }

    // update index offset if there's any claimed request

    if (totalClaimed_ > 0) index.offset = i;

    return totalClaimed_;
  }

  function _calcSync(StorageV1 storage $, IMatrixVault matrixVault, uint256 claimCount)
    internal
    view
    returns (SyncState memory)
  {
    LibRedeemQueue.Queue storage q = $.states[address(matrixVault)].queue;

    SyncState memory state = SyncState({
      queueOffset: q.offset,
      queueSize: q.size,
      totalReservedShares: 0,
      totalReservedAssets: 0,
      totalShares: matrixVault.totalSupply(),
      totalAssets: matrixVault.totalAssets()
    });

    // Use cached values from SyncState
    for (uint256 i = state.queueOffset; i < state.queueOffset + claimCount && i < state.queueSize;) {
      LibRedeemQueue.Request memory req = q.data[i];
      uint256 shares = i == 0 ? req.accumulated : req.accumulated - q.data[i - 1].accumulated;

      uint256 assetsOnRequest = _decodeRequestMetadata(req.metadata);
      uint256 assetsOnReserve = _convertToAssets(
        shares, $.states[address(matrixVault)].decimalsOffset, state.totalAssets, state.totalShares, Math.Rounding.Floor
      );

      state.totalReservedShares += shares;
      state.totalReservedAssets += Math.min(assetsOnRequest, assetsOnReserve);

      unchecked {
        ++i;
      } // Use unchecked for gas savings
    }

    return state;
  }

  function _sync(StorageV1 storage $, address executor, IMatrixVault matrixVault, uint256 claimCount)
    internal
    returns (SyncState memory)
  {
    SyncState memory state = _calcSync($, matrixVault, claimCount);

    IMatrixVault(matrixVault).withdraw(state.totalReservedAssets, address(this), address(this));

    $.states[address(matrixVault)].queue.reserve(
      executor,
      state.totalReservedShares,
      block.timestamp.toUint48(),
      /// METADATA
      _encodeReserveMetadata(state.totalShares, state.totalAssets)
    );

    emit ReserveSynced(executor, address(matrixVault), claimCount, state.totalReservedShares, state.totalReservedAssets);

    return state;
  }

  // =========================== NOTE: ASSERTIONS =========================== //

  function _assertQueueEnabled(StorageV1 storage $, address matrixVault) internal view override {
    require($.states[matrixVault].isEnabled, IReclaimQueue__QueueNotEnabled(matrixVault));
  }
}
