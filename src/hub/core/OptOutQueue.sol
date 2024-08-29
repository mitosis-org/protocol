// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { IEOLVault } from '../../interfaces/hub/core/IEolVault.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { StdError } from '../../lib/StdError.sol';
import { OptOutQueueStorageV1 } from './storage/OptOutQueueStorageV1.sol';

contract OptOutQueue is Ownable2StepUpgradeable, OptOutQueueStorageV1 {
  using SafeERC20 for IEOLVault;
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
  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 shares);
  event OptOutRequestClaimed(address indexed receiver, address indexed eolVault, uint256 assets);

  error OptOutQueue__QueueNotEnabled(address eolVault);

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

  function enable(address eolVault) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    $.states[eolVault].isEnabled = true;

    uint8 underlyingDecimals = IHubAsset(IEOLVault(eolVault).asset()).decimals();
    $.states[eolVault].underlyingDecimals = underlyingDecimals;
    $.states[eolVault].decimalsOffset = IEOLVault(eolVault).decimals() - underlyingDecimals;

    emit QueueEnabled(eolVault);
  }

  function setRedeemPeriod(address eolVault, uint256 redeemPeriod) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, eolVault);

    _queue($, eolVault).redeemPeriod = redeemPeriod;

    emit RedeemPeriodSet(eolVault, redeemPeriod);
  }

  function request(uint256 shares, address receiver, address eolVault) external {
    StorageV1 storage $ = _getStorageV1();

    _assertQueueEnabled($, eolVault);

    uint256 assets = IEOLVault(eolVault).previewRedeem(shares);

    _queue($, eolVault).enqueue(receiver, assets);

    $.ledger.recordOptOutRequest(eolVault, assets);
    IEOLVault(eolVault).redeem(shares, address(this), _msgSender());

    emit OptOutRequested(receiver, eolVault, shares);
  }

  function claim(address receiver, address eolVault) external {
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
    (uint256 totalClaimed, uint256 breadcrumb) = _claim(queue, index, cfg);

    // NOTE: burn?
    $.states[eolVault].breadcrumb += breadcrumb;

    $.ledger.recordOptOutClaim(eolVault, totalClaimed);

    IEOLVault(eolVault).withdraw(totalClaimed, receiver, address(this));

    emit OptOutRequestClaimed(receiver, eolVault, totalClaimed);
  }

  function _claim(LibRedeemQueue.Queue storage queue, LibRedeemQueue.Index storage index, ClaimConfig memory cfg)
    internal
    returns (uint256 totalClaimed, uint256 breadcrumb)
  {
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

      uint256 sharesOnRequest = _convertToShares(
        assetsOnRequest,
        cfg.decimalsOffset,
        _fetchSnapshot(cfg.hubAsset, address(cfg.eolVault), req.createdAt), //
        Math.Rounding.Floor
      );

      (uint256 reservedAt,) = queue.reservedAt(itemIndex); // isReserved can be ignored
      uint256 assetsOnResolve = _convertToAssets(
        sharesOnRequest,
        cfg.decimalsOffset,
        _fetchSnapshot(cfg.hubAsset, address(cfg.eolVault), reservedAt), //
        Math.Rounding.Floor
      );

      // apply loss if there's any reported loss while redeeming
      if (assetsOnRequest > assetsOnResolve) {
        totalClaimed += assetsOnResolve;
        breadcrumb += assetsOnRequest - assetsOnResolve;
      } else {
        totalClaimed += assetsOnRequest;
      }

      emit LibRedeemQueue.Claimed(cfg.receiver, itemIndex);
    }

    // update index offset if there's any claimed request
    if (totalClaimed > 0) {
      index.offset = i;
      queue.totalClaimed += totalClaimed + breadcrumb;
    }

    return (totalClaimed, breadcrumb);
  }

  function _sync(StorageV1 storage $, address eolVault) internal {
    IMitosisLedger.EOLAmountState memory state = $.ledger.eolAmountState(eolVault);

    _queue($, eolVault).reserve(state.idle);
    $.ledger.recordOptOutResolve(eolVault, state.idle);
  }

  function _queue(StorageV1 storage $, address eolVault) internal view returns (LibRedeemQueue.Queue storage) {
    return $.states[eolVault].queue;
  }

  function _fetchSnapshot(IHubAsset hubAsset, address eolVault, uint256 timestamp)
    internal
    view
    returns (EOLVaultSnapshot memory)
  {
    (uint256 totalAssets,,) = hubAsset.getPastTotalSnapshot(timestamp);
    (uint256 totalSupply,,) = IEOLVault(eolVault).getPastTotalSnapshot(timestamp);
    return EOLVaultSnapshot(totalAssets, totalSupply);
  }

  function _convertToShares(
    uint256 assets,
    uint8 decimalsOffset,
    EOLVaultSnapshot memory snapshot,
    Math.Rounding rounding
  ) internal view virtual returns (uint256) {
    return assets.mulDiv(snapshot.totalSupply + 10 ** decimalsOffset, snapshot.totalAssets + 1, rounding);
  }

  function _convertToAssets(
    uint256 shares,
    uint8 decimalsOffset,
    EOLVaultSnapshot memory snapshot,
    Math.Rounding rounding
  ) internal view virtual returns (uint256) {
    return shares.mulDiv(snapshot.totalAssets + 1, snapshot.totalSupply + 10 ** decimalsOffset, rounding);
  }

  function _assertQueueEnabled(StorageV1 storage $, address eolVault) internal view {
    if (!$.states[eolVault].isEnabled) revert OptOutQueue__QueueNotEnabled(eolVault);
  }
}
