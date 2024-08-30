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
import { StdError } from '../../lib/StdError.sol';
import { OptOutQueueStorageV1 } from './storage/OptOutQueueStorageV1.sol';

contract OptOutQueue is IOptOutQueue, Ownable2StepUpgradeable, OptOutQueueStorageV1 {
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
  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 assets);
  event OptOutRequestClaimed(address indexed receiver, address indexed eolVault, uint256 assets, uint256 breadcrumb);

  error OptOutQueue__QueueNotEnabled(address eolVault);
  error OptOutQueue__NothingToClaim();

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address ledger) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    if (ledger.code.length == 0) revert StdError.InvalidAddress('ledger');

    StorageV1 storage $ = _getStorageV1();

    $.ledger = IMitosisLedger(ledger);
  }

  // =========================== NOTE: VIEW FUNCTIONS =========================== //

  function redeemPeriod(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).redeemPeriod;
  }

  function getRequest(address eolVault, uint256[] calldata reqIds)
    external
    view
    returns (GetRequestResponse[] memory resp)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, eolVault);

    resp = new GetRequestResponse[](reqIds.length);
    for (uint256 i = 0; i < reqIds.length; i++) {
      resp[i].id = reqIds[i];
      resp[i].shares = $.states[eolVault].sharesByRequestId[reqIds[i]];
      resp[i].request = queue.get(reqIds[i]);
    }
    return resp;
  }

  function getRequestByReceiver(address eolVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (GetRequestByIndexResponse[] memory resp)
  {
    StorageV1 storage $ = _getStorageV1();
    LibRedeemQueue.Queue storage queue = _queue($, eolVault);

    resp = new GetRequestByIndexResponse[](idxItemIds.length);
    for (uint256 i = 0; i < idxItemIds.length; i++) {
      resp[i].id = idxItemIds[i];
      resp[i].shares = $.states[eolVault].sharesByRequestId[idxItemIds[i]];
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

  function requestAmount(address eolVault, uint256 reqId) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).amount(reqId);
  }

  function queueSize(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).size;
  }

  function queueIndexSize(address eolVault, address recipient) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).index(recipient).size;
  }

  function queueOffset(address eolVault, bool simulate) external view returns (uint256 offset) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), eolVault);
    if (simulate) (offset,) = queue.searchQueueOffset(queue.totalReserved);
    else offset = queue.offset;
    return offset;
  }

  function queueIndexOffset(address eolVault, address recipient, bool simulate) external view returns (uint256 offset) {
    LibRedeemQueue.Queue storage queue = _queue(_getStorageV1(), eolVault);
    if (simulate) (offset,) = queue.searchIndexOffset(recipient, queue.totalReserved);
    else offset = queue.index(recipient).offset;
    return offset;
  }

  function totalReserved(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).totalReserved;
  }

  function totalClaimed(address eolVault) external view returns (uint256) {
    return _queue(_getStorageV1(), eolVault).totalClaimed;
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

  function getBreadcrumb(address eolVault) external view returns (uint256) {
    return _getStorageV1().states[eolVault].breadcrumb;
  }

  // =========================== NOTE: QUEUE FUNCTIONS =========================== //

  function request(uint256 shares, address receiver, address eolVault) external returns (uint256 reqId) {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, eolVault);

    uint256 assets = IEOLVault(eolVault).previewRedeem(shares) - 1; // FIXME: tricky way to avoid rounding error

    reqId = _queue($, eolVault).enqueue(receiver, assets);
    $.states[eolVault].sharesByRequestId[reqId] = shares;

    $.ledger.recordOptOutRequest(eolVault, shares);
    IEOLVault(eolVault).redeem(shares, address(this), _msgSender());

    emit OptOutRequested(receiver, eolVault, assets);

    return reqId;
  }

  function claim(address receiver, address eolVault) external returns (uint256 totalClaimed_) {
    StorageV1 storage $ = _getStorageV1();

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

    uint256 breadcrumb;
    uint256 totalClaimedShares;
    (totalClaimed_, totalClaimedShares, breadcrumb) = _claim($, queue, index, cfg);
    if (totalClaimed_ == 0) revert OptOutQueue__NothingToClaim();

    // NOTE: burn?
    $.states[eolVault].breadcrumb += breadcrumb;

    $.ledger.recordOptOutClaim(eolVault, totalClaimed_);
    cfg.hubAsset.safeTransfer(receiver, totalClaimed_);

    emit OptOutRequestClaimed(receiver, eolVault, totalClaimed_, breadcrumb);

    return totalClaimed_;
  }

  function sync(address eolVault) external {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, eolVault);

    _sync($, eolVault);
  }

  // =========================== NOTE: CONFIG FUNCTIONS =========================== //

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

  function _queue(StorageV1 storage $, address eolVault) internal view returns (LibRedeemQueue.Queue storage) {
    return $.states[eolVault].queue;
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
  ) internal returns (uint256 totalClaimed_, uint256 totalClaimedShares, uint256 breadcrumb) {
    uint256 i = cfg.idxOffset;

    for (; i < index.size; i++) {
      if (i - cfg.idxOffset >= LibRedeemQueue.DEFAULT_CLAIM_SIZE) break;

      uint256 itemIndex = index.data[i];

      LibRedeemQueue.Request memory req = queue.data[itemIndex];
      if (req.isClaimed()) continue;
      if (itemIndex >= cfg.queueOffset) break;
      queue.data[itemIndex].claimedAt = uint48(block.timestamp);

      uint256 assetsOnRequest = itemIndex == 0
        ? req.accumulated //
        : req.accumulated - queue.data[itemIndex - 1].accumulated;

      uint256 assetsOnResolve;
      uint256 sharesOnRequest = $.states[address(cfg.eolVault)].sharesByRequestId[itemIndex];
      {
        (uint256 resolvedAt_,) = queue.resolvedAt(itemIndex, block.timestamp); // isResolved can be ignored
        (uint256 totalAssets, uint256 totalSupply) = _loadPastSnapshot(cfg.hubAsset, address(cfg.eolVault), resolvedAt_);

        assetsOnResolve = _convertToAssets(
          sharesOnRequest,
          cfg.decimalsOffset,
          // TODO: discuss
          // some simple idea - opt out queue redeeming assets immediately after request.
          // so if there's any loss reported, it'll affect the exchange rate more harder.
          // therefore, we need to calculate the exchange rate including the requested assets & shares.
          totalAssets + assetsOnRequest,
          totalSupply + sharesOnRequest,
          Math.Rounding.Floor
        );
      }

      // apply loss if there's any reported loss while redeeming
      if (assetsOnRequest > assetsOnResolve) {
        totalClaimed_ += assetsOnResolve;
        breadcrumb += assetsOnRequest - assetsOnResolve;
      } else {
        totalClaimed_ += assetsOnRequest;
      }

      totalClaimedShares += sharesOnRequest;

      emit LibRedeemQueue.Claimed(cfg.receiver, itemIndex);
    }

    // update index offset if there's any claimed request
    if (totalClaimed_ > 0) {
      index.offset = i;
      queue.totalClaimed += totalClaimed_ + breadcrumb;
    }

    return (totalClaimed_, totalClaimedShares, breadcrumb);
  }

  function _sync(StorageV1 storage $, address eolVault) internal {
    IMitosisLedger.EOLAmountState memory state = $.ledger.eolAmountState(eolVault);
    if (state.idle == 0) return; // nothing to sync

    uint256 pending = _queue($, eolVault).pending();
    if (pending == 0) return; // nothing to reserve

    uint256 pendingShares = IEOLVault(eolVault).convertToShares(pending + 1); // FIXME: tricky way to avoid rounding error
    uint256 resolveShares = Math.min(pendingShares, state.idle);
    uint256 resolveAssets = IEOLVault(eolVault).convertToAssets(resolveShares);

    _queue($, eolVault).reserve(resolveAssets);
    $.ledger.recordOptOutResolve(eolVault, resolveShares);
  }

  // =========================== NOTE: ASSERTIONS =========================== //

  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view {
    if (!$.states[eolVault].isEnabled) revert OptOutQueue__QueueNotEnabled(eolVault);
  }
}
