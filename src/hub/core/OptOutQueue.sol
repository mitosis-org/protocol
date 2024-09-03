// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { IEOLVault } from '../../interfaces/hub/core/IEolVault.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IOptOutQueue } from '../../interfaces/hub/core/IOptOutQueue.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { OptOutQueueStorageV1 } from './storage/OptOutQueueStorageV1.sol';

contract OptOutQueue is IOptOutQueue, Pausable, Ownable2StepUpgradeable, OptOutQueueStorageV1 {
  using SafeERC20 for IEOLVault;
  using SafeERC20 for IHubAsset;
  using Math for uint256;
  using LibRedeemQueue for *;

  struct ClaimConfig {
    address receiver;
    IEOLVault eolVault;
    IHubAsset hubAsset;
    uint8 decimalsOffset;
    uint256 queueOffset;
    uint256 idxOffset;
  }

  event QueueEnabled(address indexed eolVault);
  event RedeemPeriodSet(address indexed eolVault, uint256 redeemPeriod);
  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 shares, uint256 assets);
  event OptOutRequestClaimed(address indexed receiver, address indexed eolVault, uint256 shares, uint256 assets);

  error OptOutQueue__QueueNotEnabled(address eolVault);
  error OptOutQueue__NothingToClaim();

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  // =========================== NOTE: QUEUE FUNCTIONS =========================== //

  function request(uint256 shares, address receiver, address eolVault) external returns (uint256 reqId) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, eolVault);

    uint256 assets = IEOLVault(eolVault).previewRedeem(shares) - 1; // FIXME: tricky way to avoid rounding error

    reqId = _queue($, eolVault).enqueue(receiver, assets, shares);

    IEOLVault(eolVault).redeem(shares, address(this), _msgSender());

    emit OptOutRequested(receiver, eolVault, shares, assets);

    return reqId;
  }

  function claim(address receiver, address eolVault) external returns (uint256 totalClaimed_) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, eolVault);

    _sync($, eolVault);

    LibRedeemQueue.Queue storage queue = _queue($, eolVault);
    LibRedeemQueue.Index storage index = queue.index(receiver);

    queue.update();

    ClaimConfig memory cfg = ClaimConfig({
      receiver: receiver,
      eolVault: IEOLVault(eolVault),
      hubAsset: IHubAsset(IEOLVault(eolVault).asset()),
      decimalsOffset: $.states[eolVault].decimalsOffset,
      queueOffset: queue.offset,
      idxOffset: index.offset
    });

    uint256 totalClaimedShares;
    (totalClaimed_, totalClaimedShares) = _claim($, queue, index, cfg);
    if (totalClaimed_ == 0) revert OptOutQueue__NothingToClaim();

    cfg.hubAsset.safeTransfer(receiver, totalClaimed_);

    emit OptOutRequestClaimed(receiver, eolVault, totalClaimed_, totalClaimedShares);

    return totalClaimed_;
  }

  function sync(address eolVault) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, eolVault);

    _sync($, eolVault);
  }

  // =========================== NOTE: CONFIG FUNCTIONS =========================== //

  function pause() external onlyOwner {
    _pause();
  }

  function pause(bytes4 sig) external onlyOwner {
    _pause(sig);
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function unpause(bytes4 sig) external onlyOwner {
    _unpause(sig);
  }

  function enable(address eolVault) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    $.states[eolVault].isEnabled = true;

    uint8 underlyingDecimals = IHubAsset(IEOLVault(eolVault).asset()).decimals();
    $.states[eolVault].underlyingDecimals = underlyingDecimals;
    $.states[eolVault].decimalsOffset = IEOLVault(eolVault).decimals() - underlyingDecimals;

    emit QueueEnabled(eolVault);
  }

  function setRedeemPeriod(address eolVault, uint256 redeemPeriod_) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, eolVault);

    _queue($, eolVault).redeemPeriod = redeemPeriod_;

    emit RedeemPeriodSet(eolVault, redeemPeriod_);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  function _convertToAssets(
    uint256 shares,
    uint8 decimalsOffset,
    uint256 totalAssets,
    uint256 totalSupply,
    Math.Rounding rounding
  ) internal pure virtual returns (uint256) {
    return shares.mulDiv(totalAssets + 1, totalSupply + 10 ** decimalsOffset, rounding);
  }

  function _loadPastSnapshot(IHubAsset hubAsset, address eolVault, uint256 timestamp)
    internal
    view
    returns (uint256 totalAssets, uint256 totalSupply)
  {
    // prevent future lookup
    if (timestamp == block.timestamp) {
      totalAssets = IEOLVault(eolVault).totalAssets();
      totalSupply = IEOLVault(eolVault).totalSupply();
    } else {
      (totalAssets,,) = hubAsset.getPastSnapshot(eolVault, timestamp);
      (totalSupply,,) = IEOLVault(eolVault).getPastTotalSnapshot(timestamp);
    }
    return (totalAssets, totalSupply);
  }

  function _claim(
    StorageV1 storage $,
    LibRedeemQueue.Queue storage queue,
    LibRedeemQueue.Index storage index,
    ClaimConfig memory cfg
  ) internal returns (uint256 totalClaimed_, uint256 totalClaimedShares) {
    uint256 i = cfg.idxOffset;

    for (; i < index.size; i++) {
      if (i - cfg.idxOffset >= LibRedeemQueue.DEFAULT_CLAIM_SIZE) break;

      uint256 reqId = index.data[i];

      LibRedeemQueue.Request memory req = queue.data[reqId];
      if (req.isClaimed()) continue;
      if (reqId >= cfg.queueOffset) break;
      queue.data[reqId].claimedAt = uint48(block.timestamp);

      uint256 assetsOnRequest =
        reqId == 0 ? req.accumulatedAssets : req.accumulatedAssets - queue.data[reqId - 1].accumulatedAssets;

      uint256 assetsOnResolve;
      uint256 sharesOnRequest = $.states[address(cfg.eolVault)].accumulatedAssetsByRequestId[reqId];
      {
        (uint256 resolvedAt_,) = queue.resolvedAt(reqId, block.timestamp); // isResolved can be ignored
        (uint256 totalAssets, uint256 totalSupply) = _loadPastSnapshot(cfg.hubAsset, address(cfg.eolVault), resolvedAt_);

        assetsOnResolve =
          _convertToAssets(sharesOnRequest, cfg.decimalsOffset, totalAssets, totalSupply, Math.Rounding.Floor);
      }

      // apply loss if there's any reported loss while redeeming
      if (assetsOnRequest > assetsOnResolve) {
        totalClaimed_ += assetsOnResolve;
      } else {
        totalClaimed_ += assetsOnRequest;
      }

      totalClaimedShares += sharesOnRequest;

      emit LibRedeemQueue.Claimed(cfg.receiver, reqId);
    }

    // update index offset if there's any claimed request
    if (totalClaimed_ > 0) {
      index.offset = i;
      queue.totalClaimed += totalClaimed_;
    }

    return (totalClaimed_, totalClaimedShares);
  }

  function _sync(StorageV1 storage $, address eolVault) internal {
    uint256 pending = _queue($, eolVault).pending();
    if (pending == 0) return; // nothing to reserve

    uint256 pendingShares = IEOLVault(eolVault).convertToShares(pending + 1); // FIXME: tricky way to avoid rounding error
    uint256 resolveShares = Math.min(pendingShares, 0); // FIXME
    uint256 resolveAssets = IEOLVault(eolVault).convertToAssets(resolveShares);

    _queue($, eolVault).reserve(resolveAssets); // FIXME
  }

  // =========================== NOTE: ASSERTIONS =========================== //

  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view {
    if (!$.states[eolVault].isEnabled) revert OptOutQueue__QueueNotEnabled(eolVault);
  }
}
