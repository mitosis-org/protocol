// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';
import { BaseHandler } from './BaseHandler.sol';
import { LibDistributorRewardMetadata, RewardTWABMetadata } from './LibDistributorRewardMetadata.sol';
import { TWABRewardDistributorStorageV1 } from './TWABRewardDistributorStorageV1.sol';
import { StdError } from '../../lib/StdError.sol';

contract TWABRewardDistributor is
  BaseHandler,
  ITWABRewardDistributor,
  TWABRewardDistributorStorageV1,
  AccessControlEnumerableUpgradeable
{
  using LibDistributorRewardMetadata for RewardTWABMetadata;
  using LibDistributorRewardMetadata for bytes;
  using TWABSnapshotsUtils for ITWABSnapshots;

  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  uint48 public immutable batchPeriod;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor(uint48 batchPeriod_) BaseHandler(HandlerType.Endpoint, DistributionType.TWAB, 'TWAB Reward Distributor') {
    _disableInitializers();
    batchPeriod = batchPeriod_;
  }

  function initialize(address admin, uint48 twabPeriod_, uint256 rewardPrecision_) public initializer {
    __BaseHandler_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(DISPATCHER_ROLE, DEFAULT_ADMIN_ROLE);

    StorageV1 storage $ = _getStorageV1();

    _setTWABPeriod($, twabPeriod_);
    _setRewardPrecision($, rewardPrecision_);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function encodeMetadata(uint48 batchTimestamp) external pure returns (bytes memory) {
    return RewardTWABMetadata({ batchTimestamp: batchTimestamp }).encode();
  }

  function claimable(address eolVault, address account, address reward, bytes calldata metadata)
    external
    view
    returns (bool)
  {
    return claimableAmount(eolVault, account, reward, metadata) > 0;
  }

  function claimableAmount(address eolVault, address account, address reward, bytes calldata metadata)
    public
    view
    returns (uint256)
  {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    uint48 batchTimestamp = twabMetadata.batchTimestamp;

    StorageV1 storage $ = _getStorageV1();
    Receipt storage receipt = _receipt($, account, eolVault, reward, batchTimestamp);

    if (receipt.claimed) return 0;

    uint256 userReward = _calculateUserReward($, eolVault, account, reward, batchTimestamp);

    return userReward - receipt.claimedAmount;
  }

  function getFirstBatchTimestamp(address eolVault, address reward) external view returns (uint48) {
    AssetRewards storage assetRewards = _assetRewards(eolVault, reward);
    return assetRewards.batchTimestamps.length == 0 ? 0 : assetRewards.batchTimestamps[0];
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function claim(address eolVault, address reward, bytes calldata metadata) external {
    claim(eolVault, _msgSender(), reward, metadata);
  }

  function claim(address eolVault, address receiver, address reward, bytes calldata metadata) public {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimAllReward(eolVault, _msgSender(), receiver, reward, twabMetadata.batchTimestamp);
  }

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    claim(eolVault, _msgSender(), reward, amount, metadata);
  }

  function claim(address eolVault, address receiver, address reward, uint256 amount, bytes calldata metadata) public {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimPartialReward(eolVault, _msgSender(), receiver, reward, twabMetadata.batchTimestamp, amount);
  }

  /**
   * @inheritdoc BaseHandler
   */
  function _isDispatchable(address dispathcer) internal view override returns (bool) {
    return hasRole(DISPATCHER_ROLE, dispathcer);
  }

  /**
   * @inheritdoc BaseHandler
   * @dev use current timestamp and eolVault if metadata is not provided
   */
  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) internal override {
    require(metadata.length == 0, StdError.InvalidParameter('metadata'));

    StorageV1 storage $ = _getStorageV1();

    IERC20(reward).transferFrom(_msgSender(), address(this), amount);

    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);
    uint48[] storage batchTimestamps = assetRewards.batchTimestamps;

    // NOTE: We round `batchTimestamp` up to midnight because it's
    // convenient for future calls. It ensures that the batch reward for
    // all `eolVault` has the same `batchTimestamp` range.
    uint48 batchTimestamp = _roundUpToMidnight(IERC6372(eolVault).clock());

    if (batchTimestamps.length == 0) {
      assetRewards.batchTimestamps.push(batchTimestamp);
      assetRewards.lastBatchTimestamp = batchTimestamp;
    } else {
      require(
        batchTimestamp >= assetRewards.lastBatchTimestamp, ITWABRewardDistributor__BatchTimestampAlreadyFinalized()
      );

      if (batchTimestamp > assetRewards.lastBatchTimestamp) {
        assetRewards.batchTimestamps.push(batchTimestamp);
        assetRewards.lastBatchTimestamp = batchTimestamp;
      }
    }

    assetRewards.batchRewards[batchTimestamp] += amount;

    emit RewardHandled(eolVault, reward, amount, distributionType(), metadata, abi.encode(batchTimestamp));
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _roundUpToMidnight(uint48 timestamp) internal view returns (uint48) {
    uint48 currentMidnight = timestamp - (timestamp % batchPeriod);
    uint48 nextMidnight = currentMidnight + batchPeriod;
    return nextMidnight;
  }

  function _lastFinalizedBatchTimestamp(address eolVault) internal view returns (uint48) {
    return _roundUpToMidnight(IERC6372(eolVault).clock()) - batchPeriod;
  }

  function _claimAllReward(address eolVault, address account, address receiver, address reward, uint48 batchTimestamp)
    internal
  {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);
    Receipt storage receipt = assetRewards.receipts[batchTimestamp][account];

    uint48 lastClaimedBatchTimestamp = assetRewards.lastClaimedBatchTimestamps[account];
    uint48 lastFinalizedBatchTimestamp = _lastFinalizedBatchTimestamp(eolVault);
    require(batchTimestamp > lastClaimedBatchTimestamp, ITWABRewardDistributor__BatchTimestampAlreadyClaimed());
    require(batchTimestamp <= lastFinalizedBatchTimestamp, ITWABRewardDistributor__BatchTimestampNotFinalized());

    uint256 userReward = _calculateUserReward($, eolVault, account, reward, batchTimestamp);
    uint256 claimableReward = userReward - receipt.claimedAmount;

    if (claimableReward > 0) {
      _updateReceipt(receipt, userReward, claimableReward);
      assetRewards.lastClaimedBatchTimestamps[account] = batchTimestamp;

      IERC20(reward).transfer(receiver, claimableReward);
      emit Claimed(eolVault, account, receiver, reward, claimableReward);
    }
  }

  function _claimPartialReward(
    address eolVault,
    address account,
    address receiver,
    address reward,
    uint48 batchTimestamp,
    uint256 amount
  ) internal {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);
    Receipt storage receipt = assetRewards.receipts[batchTimestamp][account];

    uint48 lastClaimedBatchTimestamp = assetRewards.lastClaimedBatchTimestamps[account];
    uint48 lastFinalizedBatchTimestamp = _lastFinalizedBatchTimestamp(eolVault);
    require(batchTimestamp > lastClaimedBatchTimestamp, ITWABRewardDistributor__BatchTimestampAlreadyClaimed());
    require(batchTimestamp <= lastFinalizedBatchTimestamp, ITWABRewardDistributor__BatchTimestampNotFinalized());

    uint256 userReward = _calculateUserReward($, eolVault, account, reward, batchTimestamp);
    uint256 claimableReward = userReward - receipt.claimedAmount;

    require(claimableReward >= amount, ITWABRewardDistributor__InsufficientReward());

    bool totalClaimed = _updateReceipt(receipt, userReward, amount);
    if (totalClaimed) {
      assetRewards.lastClaimedBatchTimestamps[account] = batchTimestamp;
    }

    IERC20(reward).transfer(receiver, amount);
    emit Claimed(account, receiver, eolVault, reward, amount);
  }

  function _updateReceipt(Receipt storage receipt, uint256 userReward, uint256 claimedReward)
    internal
    returns (bool totalClaimed)
  {
    receipt.claimedAmount += claimedReward;
    if (receipt.claimedAmount == userReward) {
      receipt.claimed = true;
      return true;
    }
    return false;
  }

  function _calculateUserRatio(StorageV1 storage $, address eolVault, address account, uint48 batchTimestamp)
    internal
    view
    returns (uint256)
  {
    uint48 startsAt;
    startsAt = $.twabPeriod > batchTimestamp ? 0 : batchTimestamp - $.twabPeriod;

    uint48 endsAt = batchTimestamp;

    ITWABSnapshots criteria = ITWABSnapshots(eolVault);

    uint256 totalTWAB = criteria.getTotalTWABByTimestampRange(startsAt, endsAt);
    if (totalTWAB == 0) return 0;

    uint256 userTWAB = criteria.getAccountTWABByTimestampRange(account, startsAt, endsAt);
    if (userTWAB == 0) return 0;

    uint256 precision = $.rewardPrecision;
    uint256 userRatio = Math.mulDiv(userTWAB, precision, totalTWAB);
    if (userRatio == 0) return 0;

    return userRatio;
  }

  function _calculateUserReward(
    StorageV1 storage $,
    address eolVault,
    address account,
    address reward,
    uint48 batchTimestamp
  ) internal view returns (uint256) {
    uint256 totalReward = _batchRewards($, eolVault, reward, batchTimestamp);
    uint256 userRatio = _calculateUserRatio($, eolVault, account, batchTimestamp);
    uint256 precision = $.rewardPrecision;
    return Math.mulDiv(totalReward, userRatio, precision);
  }
}
