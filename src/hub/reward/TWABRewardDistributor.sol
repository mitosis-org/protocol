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

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() BaseHandler(HandlerType.Endpoint, DistributionType.TWAB, 'TWAB Reward Distributor') {
    _disableInitializers();
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

  function encodeMetadata(address twabCriteria, uint48 rewardedAt) external pure returns (bytes memory) {
    return RewardTWABMetadata({ twabCriteria: twabCriteria, rewardedAt: rewardedAt }).encode();
  }

  function claimable(address account, address reward, bytes calldata metadata) external view returns (bool) {
    return claimableAmount(account, reward, metadata) > 0;
  }

  function claimableAmount(address account, address reward, bytes calldata metadata) public view returns (uint256) {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();

    address twabCriteria = twabMetadata.twabCriteria;
    uint48 rewardedAt = twabMetadata.rewardedAt;

    StorageV1 storage $ = _getStorageV1();
    Receipt storage receipt = _receipt($, account, twabCriteria, reward, rewardedAt);

    if (receipt.claimed) return 0;

    uint256 userReward = _calculateUserReward($, twabCriteria, account, reward, rewardedAt);

    return userReward - receipt.claimedAmount;
  }

  function getFirstBatchTimestamp(address twabCriteria, address reward) external view returns (uint48) {
    AssetRewards storage assetRewards = _assetRewards(twabCriteria, reward);
    return assetRewards.batchTimestamps.length == 0 ? 0 : assetRewards.batchTimestamps[0];
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function claim(address reward, bytes calldata metadata) external {
    claim(_msgSender(), reward, metadata);
  }

  function claim(address receiver, address reward, bytes calldata metadata) public {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimAllReward(_msgSender(), receiver, twabMetadata.twabCriteria, reward, twabMetadata.rewardedAt);
  }

  function claim(address reward, uint256 amount, bytes calldata metadata) external {
    claim(_msgSender(), reward, amount, metadata);
  }

  function claim(address receiver, address reward, uint256 amount, bytes calldata metadata) public {
    RewardTWABMetadata memory twabMetadata = metadata.decodeRewardTWABMetadata();
    _claimPartialReward(_msgSender(), receiver, twabMetadata.twabCriteria, reward, twabMetadata.rewardedAt, amount);
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
    StorageV1 storage $ = _getStorageV1();

    IERC20(reward).transferFrom(_msgSender(), address(this), amount);

    RewardTWABMetadata memory twabMetadata = metadata.length == 0
      ? RewardTWABMetadata({ twabCriteria: eolVault, rewardedAt: IERC6372(eolVault).clock() })
      : metadata.decodeRewardTWABMetadata();
    _assertValidRewardMetadata(twabMetadata);

    address twabCriteria = twabMetadata.twabCriteria;
    uint48 rewardedAt = twabMetadata.rewardedAt;

    AssetRewards storage assetRewards = _assetRewards($, twabCriteria, reward);
    uint48[] storage batchTimestamps = assetRewards.batchTimestamps;

    uint48 batchTimestamp;

    if (batchTimestamps.length == 0) {
      // note(ray): We round `batchTimestamp` up to midnight because it's
      // convenient for future calls. It ensures that the batch reward for
      // all `twabCriteria` has the same `batchTimestamp` range.
      batchTimestamp = _roundUpToMidnight(rewardedAt + $.twabPeriod);
      assetRewards.batchTimestamps.push(batchTimestamp);
      assetRewards.lastBatchTimestamp = batchTimestamp;
    } else {
      uint48 prevBatchTimestamp = assetRewards.lastBatchTimestamp - $.twabPeriod;
      uint48 nextBatchTimestamp = assetRewards.lastBatchTimestamp + $.twabPeriod;

      // Case 1: Move to next batch
      if (nextBatchTimestamp <= rewardedAt + $.twabPeriod) {
        batchTimestamp = nextBatchTimestamp;
        assetRewards.batchTimestamps.push(batchTimestamp);
        assetRewards.lastBatchTimestamp = batchTimestamp;
      } else if (prevBatchTimestamp < rewardedAt + $.twabPeriod) {
        // Case 2: Handle previous rewardedAt
        batchTimestamp = _findBatchTimestamp(assetRewards.batchTimestamps[0], rewardedAt, $.twabPeriod);
      } else {
        // Case 3: In current batch
        batchTimestamp = assetRewards.lastBatchTimestamp;
      }
    }

    assetRewards.batchRewards[batchTimestamp] += amount;

    emit RewardHandled(twabCriteria, reward, amount, batchTimestamp, distributionType(), metadata);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _roundUpToMidnight(uint48 timestamp) internal pure returns (uint48) {
    uint48 currentMidnight = timestamp - (timestamp % 1 days);
    uint48 nextMidnight = currentMidnight + 1 days;
    return nextMidnight;
  }

  function _findBatchTimestamp(uint48 startBatchTimestamp, uint48 timestamp, uint48 period)
    internal
    pure
    returns (uint48)
  {
    if (timestamp <= startBatchTimestamp) {
      return startBatchTimestamp;
    }
    uint48 timeDifference = timestamp - startBatchTimestamp;
    uint48 periodsPassed = (timeDifference + period - 1) / period;
    uint48 batchTimestamp = startBatchTimestamp + (periodsPassed * period);
    return _roundUpToMidnight(batchTimestamp);
  }

  function _claimAllReward(address account, address receiver, address twabCriteria, address reward, uint48 rewardedAt)
    internal
  {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, twabCriteria, reward);
    Receipt storage receipt = assetRewards.receipts[rewardedAt][account];

    uint256 userReward = _calculateUserReward($, twabCriteria, account, reward, rewardedAt);
    uint256 claimableReward = userReward - receipt.claimedAmount;

    if (claimableReward > 0) {
      _updateReceipt(receipt, userReward, claimableReward);
      IERC20(reward).transfer(receiver, claimableReward);
      emit Claimed(account, receiver, twabCriteria, reward, claimableReward);
    }
  }

  function _claimPartialReward(
    address account,
    address receiver,
    address twabCriteria,
    address reward,
    uint48 rewardedAt,
    uint256 amount
  ) internal {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, twabCriteria, reward);
    Receipt storage receipt = assetRewards.receipts[rewardedAt][account];

    uint256 userReward = _calculateUserReward($, twabCriteria, account, reward, rewardedAt);
    uint256 claimableReward = userReward - receipt.claimedAmount;

    require(claimableReward >= amount, ITWABRewardDistributor__InsufficientReward());

    _updateReceipt(receipt, userReward, amount);
    IERC20(reward).transfer(receiver, amount);

    emit Claimed(account, receiver, twabCriteria, reward, amount);
  }

  function _updateReceipt(Receipt storage receipt, uint256 userReward, uint256 claimedReward) internal {
    receipt.claimedAmount += claimedReward;
    if (receipt.claimedAmount == userReward) {
      receipt.claimed = true;
    }
  }

  function _calculateUserRatio(StorageV1 storage $, address twabCriteria, address account, uint48 rewardedAt)
    internal
    view
    returns (uint256)
  {
    uint48 startsAt;
    startsAt = $.twabPeriod > rewardedAt ? 0 : rewardedAt - $.twabPeriod;

    uint48 endsAt = rewardedAt;

    ITWABSnapshots criteria = ITWABSnapshots(twabCriteria);

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
    address twabCriteria,
    address account,
    address reward,
    uint48 rewardedAt
  ) internal view returns (uint256) {
    uint256 totalReward = _batchRewards($, twabCriteria, reward, rewardedAt);
    uint256 userRatio = _calculateUserRatio($, twabCriteria, account, rewardedAt);
    uint256 precision = $.rewardPrecision;
    return Math.mulDiv(totalReward, userRatio, precision);
  }

  function _assertValidRewardMetadata(RewardTWABMetadata memory metadata) internal view {
    require(metadata.twabCriteria != address(0), ITWABRewardDistributor__InvalidTWABCriteria());
    // TODO(ray): handleReward.Case 2, we should consider removing this
    // require, which means that the `batchTimestamps` array will no
    // longer be sorted.
    require(metadata.rewardedAt == block.timestamp, ITWABRewardDistributor__InvalidRewardedAt());
  }
}
