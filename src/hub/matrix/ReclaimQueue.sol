// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { IReclaimQueue } from '../../interfaces/hub/matrix/IReclaimQueue.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { ReclaimQueueStorageV1 } from './ReclaimQueueStorageV1.sol';

contract ReclaimQueue is IReclaimQueue, Pausable, Ownable2StepUpgradeable, ReclaimQueueStorageV1 {
  using SafeERC20 for IMatrixVault;
  using SafeERC20 for IHubAsset;
  using SafeCast for uint256;
  using Math for uint256;
  using LibRedeemQueue for *;

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

  function request(uint256 shares, address receiver, address matrixVault) external returns (uint256 reqId) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertQueueEnabled($, matrixVault);

    IMatrixVault(matrixVault).safeTransferFrom(_msgSender(), address(this), shares);
    uint256 assets = IMatrixVault(matrixVault).previewRedeem(shares) - 1; // FIXME: tricky way to avoid rounding error
    LibRedeemQueue.Queue storage queue = $.states[matrixVault].queue;
    reqId = queue.enqueue(receiver, shares, assets, block.timestamp.toUint48());

    emit ReclaimRequested(receiver, matrixVault, shares, assets);

    return reqId;
  }

  function claim(address receiver, address matrixVault) external returns (uint256 totalClaimed_) {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
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
    uint256 totalClaimedWithoutImpact;
    (totalClaimed_, totalClaimedWithoutImpact) = _claim(queue, index, cfg);
    require(totalClaimed_ > 0, IReclaimQueue__NothingToClaim());

    // send total claim amount to receiver
    cfg.hubAsset.safeTransfer(receiver, totalClaimed_);

    // send diff to matrixVault if there's any yield
    (uint256 impact, bool loss) = _abssub(totalClaimedWithoutImpact, totalClaimed_);
    if (loss) {
      cfg.hubAsset.safeTransfer(matrixVault, impact);
      emit ReclaimYieldReported(receiver, matrixVault, impact);
    }

    emit ReclaimRequestClaimed(
      receiver,
      matrixVault,
      totalClaimed_,
      impact,
      impact == 0 ? ImpactType.None : loss ? ImpactType.Loss : ImpactType.Yield
    );

    return totalClaimed_;
  }

  function sync(address matrixVault, uint256 assets) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyAssetManager($);
    _assertQueueEnabled($, matrixVault);

    _sync($, IMatrixVault(matrixVault), assets);
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
    return IMatrixVault(matrixVault).totalAssets() - queue.pending() - assetManager.matrixAlloc(matrixVault);
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
      queue.data[reqId].claimedAt = cfg.timestamp.toUint48();

      uint256 assetsOnRequest = req.accumulatedAssets;
      uint256 sharesOnRequest = req.accumulatedShares;
      uint256 claimed;
      {
        if (reqId != 0) {
          LibRedeemQueue.Request memory prevReq = queue.data[reqId - 1];
          assetsOnRequest -= prevReq.accumulatedAssets;
          sharesOnRequest -= prevReq.accumulatedShares;
        }

        (LibRedeemQueue.ReserveLog memory reserveLog,) = queue.reserveLog(reqId); // found can be ignored

        uint256 assetsOnReserve = _convertToAssets(
          sharesOnRequest, cfg.decimalsOffset, reserveLog.totalAssets, reserveLog.totalShares, Math.Rounding.Floor
        );

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

  function _sync(StorageV1 storage $, IMatrixVault matrixVault, uint256 assets) internal {
    MatrixVaultState storage matrixVaultState = $.states[address(matrixVault)];

    uint256 shares = matrixVault.withdraw(assets, address(this), address(this));

    matrixVaultState.queue.reserve(
      shares, assets, matrixVault.totalSupply(), matrixVault.totalAssets(), block.timestamp.toUint48()
    );
  }

  // =========================== NOTE: ASSERTIONS =========================== //

  function _assertQueueEnabled(StorageV1 storage $, address matrixVault) internal view override {
    require($.states[matrixVault].isEnabled, IReclaimQueue__QueueNotEnabled(matrixVault));
  }
}
