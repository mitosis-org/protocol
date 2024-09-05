// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IOptOutQueue } from '../../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEolVault.sol';
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

  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 shares, uint256 assets);
  event OptOutYieldReported(address indexed receiver, address indexed eolVault, uint256 yield);
  event OptOutRequestClaimed(
    address indexed receiver, address indexed eolVault, uint256 claimed, uint256 impact, ImpactType impactType
  );

  error OptOutQueue__QueueNotEnabled(address eolVault);
  error OptOutQueue__NothingToClaim();

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address assetManager) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();

    _setAssetManager($, assetManager);
  }

  // =========================== NOTE: QUEUE FUNCTIONS =========================== //

  function request(uint256 shares, address receiver, address eolVault) external returns (uint256 reqId) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, eolVault);

    uint256 assets = IEOLVault(eolVault).previewRedeem(shares) - 1; // FIXME: tricky way to avoid rounding error

    LibRedeemQueue.Queue storage queue = $.states[eolVault].queue;
    reqId = queue.enqueue(receiver, assets, shares);

    emit OptOutRequested(receiver, eolVault, shares, assets);

    return reqId;
  }

  function claim(address receiver, address eolVault) external returns (uint256 totalClaimed_) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, eolVault);

    _sync($, eolVault);

    LibRedeemQueue.Queue storage queue = $.states[eolVault].queue;
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

    // run actual claim logic
    uint256 totalClaimedWithoutImpact;
    (totalClaimed_, totalClaimedWithoutImpact) = _claim(queue, index, cfg);
    if (totalClaimed_ == 0) revert OptOutQueue__NothingToClaim();

    // send total claim amount to receiver
    cfg.hubAsset.safeTransfer(receiver, totalClaimed_);

    // send diff to eolVault if there's any yield
    (uint256 impact, bool loss) = _abs(totalClaimedWithoutImpact, totalClaimed_);
    if (loss) {
      cfg.hubAsset.safeTransfer(eolVault, impact);
      emit OptOutYieldReported(receiver, eolVault, impact);
    }

    emit OptOutRequestClaimed(
      receiver,
      eolVault,
      totalClaimed_,
      impact,
      impact == 0 ? ImpactType.None : loss ? ImpactType.Loss : ImpactType.Yield
    );

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
    _enableQueue(_getStorageV1(), eolVault);
  }

  function setAssetManager(address assetManager) external onlyOwner {
    _setAssetManager(_getStorageV1(), assetManager);
  }

  function setRedeemPeriod(address eolVault, uint256 redeemPeriod_) external onlyOwner {
    _setRedeemPeriod(_getStorageV1(), eolVault, redeemPeriod_);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  function _abs(uint256 x, uint256 y) private pure returns (uint256, bool) {
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

  function _idle(LibRedeemQueue.Queue storage queue, IAssetManager assetManager, address eolVault)
    internal
    view
    returns (uint256)
  {
    return IEOLVault(eolVault).totalAssets() - queue.pending() - assetManager.eolAlloc(eolVault);
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

  function _claim(LibRedeemQueue.Queue storage queue, LibRedeemQueue.Index storage index, ClaimConfig memory cfg)
    internal
    returns (uint256 totalClaimed_, uint256 totalClaimedWithoutImpact)
  {
    uint256 i = cfg.idxOffset;

    for (; i < index.size; i++) {
      if (i - cfg.idxOffset >= LibRedeemQueue.DEFAULT_CLAIM_SIZE) break;

      uint256 reqId = index.data[i];

      LibRedeemQueue.Request memory req = queue.data[reqId];
      if (req.isClaimed()) continue;
      if (reqId >= cfg.queueOffset) break;
      queue.data[reqId].claimedAt = uint48(block.timestamp);

      uint256 assetsOnRequest = req.accumulatedAssets;
      uint256 sharesOnRequest = req.accumulatedShares;
      uint256 claimed;
      {
        if (reqId != 0) {
          LibRedeemQueue.Request memory prevReq = queue.data[reqId - 1];
          assetsOnRequest -= prevReq.accumulatedAssets;
          sharesOnRequest -= prevReq.accumulatedShares;
        }

        (uint256 reservedAt_,) = queue.reservedAt(reqId); // isResolved can be ignored
        (uint256 totalAssets, uint256 totalSupply) = _loadPastSnapshot(cfg.hubAsset, address(cfg.eolVault), reservedAt_);

        uint256 assetsOnReserve =
          _convertToAssets(sharesOnRequest, cfg.decimalsOffset, totalAssets, totalSupply, Math.Rounding.Floor);

        claimed = Math.min(assetsOnRequest, assetsOnReserve);
      }

      totalClaimedWithoutImpact += assetsOnRequest;
      totalClaimed_ += claimed;

      emit LibRedeemQueue.Claimed(cfg.receiver, reqId);
    }

    // update index offset if there's any claimed request
    if (totalClaimedWithoutImpact > 0) {
      index.offset = i;
      queue.totalClaimedAssets += totalClaimedWithoutImpact;
    }

    return (totalClaimed_, totalClaimedWithoutImpact);
  }

  function _sync(StorageV1 storage $, address eolVault) internal {
    LibRedeemQueue.Queue storage queue = $.states[eolVault].queue;

    uint256 pending = queue.pending();
    if (pending == 0) return; // no pending assets to reserve

    uint256 idle = _idle(queue, $.assetManager, eolVault);
    if (idle == 0) return; // no idle assets to reserve

    uint256 reserveAssets = Math.min(pending, idle);
    IEOLVault(eolVault).withdraw(reserveAssets, address(this), address(this));

    queue.reserve(reserveAssets);
  }

  // =========================== NOTE: ASSERTIONS =========================== //

  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view override {
    if (!$.states[eolVault].isEnabled) revert OptOutQueue__QueueNotEnabled(eolVault);
  }
}
