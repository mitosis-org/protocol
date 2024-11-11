// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { StdError } from '../../lib/StdError.sol';
import { BaseHandler } from './BaseHandler.sol';
import { TWABRewardDistributorStorageV1 } from './TWABRewardDistributorStorageV1.sol';

contract TWABRewardDistributor is
  BaseHandler,
  ITWABRewardDistributor,
  TWABRewardDistributorStorageV1,
  AccessControlEnumerableUpgradeable
{
  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  uint48 public immutable batchPeriod;

  // TODO(thai): it is only for testing during development in our team.
  //   It should be removed before exposing our app to senseis
  uint48 public constant TEST_BATCH_PERIOD = 30 minutes;

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

  function getFirstBatchTimestamp(address eolVault, address reward) external view returns (uint48) {
    AssetRewards storage assetRewards = _assetRewards(_getStorageV1(), eolVault, reward);
    return assetRewards.firstBatchTimestamp;
  }

  function getLastClaimedBatchTimestamp(address eolVault, address account, address reward)
    external
    view
    returns (uint48)
  {
    return _assetRewards(_getStorageV1(), eolVault, reward).lastClaimedBatchTimestamps[account];
  }

  function getLastFinalizedBatchTimestamp(address eolVault) external view returns (uint48) {
    return _lastFinalizedBatchTimestamp(eolVault);
  }

  function isClaimableBatch(address eolVault, address account, address reward, uint48 batchTimestamp)
    external
    view
    returns (bool)
  {
    return claimableAmountForBatch(eolVault, account, reward, batchTimestamp) > 0;
  }

  function claimableAmountForBatch(address eolVault, address account, address reward, uint48 batchTimestamp)
    public
    view
    returns (uint256)
  {
    return _claimableAmountForBatch(_getStorageV1(), eolVault, account, reward, batchTimestamp);
  }

  function claimableAmount(address eolVault, address account, address reward, uint48 toTimestamp)
    external
    view
    returns (uint256)
  {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);

    uint48 lastFinalizedBatchTimestamp = _lastFinalizedBatchTimestamp(eolVault);
    toTimestamp = toTimestamp < lastFinalizedBatchTimestamp ? toTimestamp : lastFinalizedBatchTimestamp;

    // TODO(thai): it should be aligned with batch period
    uint48 batchTimestamp = assetRewards.lastClaimedBatchTimestamps[account] == 0
      ? assetRewards.firstBatchTimestamp
      : assetRewards.lastClaimedBatchTimestamps[account] + TEST_BATCH_PERIOD;
    if (batchTimestamp == 0 || batchTimestamp > toTimestamp) return 0;

    uint256 totalClaimableAmount = 0;
    do {
      totalClaimableAmount += _claimableAmountForBatch($, eolVault, account, reward, batchTimestamp);
      batchTimestamp = batchTimestamp + TEST_BATCH_PERIOD;
    } while (batchTimestamp <= toTimestamp);

    return totalClaimableAmount;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function claim(address eolVault, address receiver, address reward, uint48 toTimestamp)
    external
    returns (uint256 claimedAmount)
  {
    StorageV1 storage $ = _getStorageV1();
    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);
    address account = _msgSender();

    uint48 lastFinalizedBatchTimestamp = _lastFinalizedBatchTimestamp(eolVault);
    toTimestamp = toTimestamp < lastFinalizedBatchTimestamp ? toTimestamp : lastFinalizedBatchTimestamp;

    // TODO(thai): it should be aligned with batch period
    uint48 startBatchTimestamp = assetRewards.lastClaimedBatchTimestamps[account] == 0
      ? assetRewards.firstBatchTimestamp
      : assetRewards.lastClaimedBatchTimestamps[account] + TEST_BATCH_PERIOD;
    uint48 batchTimestamp = startBatchTimestamp;
    if (batchTimestamp == 0 || batchTimestamp > toTimestamp) return 0;

    uint256 totalRewards = 0;
    do {
      totalRewards += _calculateUserReward($, eolVault, account, reward, batchTimestamp);
      batchTimestamp = batchTimestamp + TEST_BATCH_PERIOD;
    } while (batchTimestamp <= toTimestamp);

    assetRewards.lastClaimedBatchTimestamps[account] = batchTimestamp - TEST_BATCH_PERIOD;
    if (totalRewards > 0) {
      IERC20(reward).transfer(receiver, totalRewards);
    }

    emit Claimed(
      eolVault,
      account,
      receiver,
      reward,
      totalRewards,
      startBatchTimestamp,
      assetRewards.lastClaimedBatchTimestamps[account]
    );

    return totalRewards;
  }

  /**
   * @inheritdoc BaseHandler
   */
  function _isDispatchable(address dispathcer) internal view override returns (bool) {
    return hasRole(DISPATCHER_ROLE, dispathcer);
  }

  /**
   * @inheritdoc BaseHandler
   */
  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata) internal override {
    StorageV1 storage $ = _getStorageV1();

    IERC20(reward).transferFrom(_msgSender(), address(this), amount);

    AssetRewards storage assetRewards = _assetRewards($, eolVault, reward);

    // NOTE: We round `batchTimestamp` up to midnight because it's
    // convenient for future calls. It ensures that the batch reward for
    // all `eolVault` has the same `batchTimestamp` range.
    uint48 batchTimestamp = _roundUpToMidnight(IERC6372(eolVault).clock());

    assetRewards.batchRewards[batchTimestamp] += amount;
    if (assetRewards.firstBatchTimestamp == 0 || assetRewards.firstBatchTimestamp > batchTimestamp) {
      assetRewards.firstBatchTimestamp = batchTimestamp;
    }

    emit RewardHandled(eolVault, reward, amount, distributionType(), '', abi.encode(batchTimestamp));
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _roundUpToMidnight(uint48 timestamp) internal view returns (uint48) {
    uint48 currentMidnight = timestamp - (timestamp % TEST_BATCH_PERIOD);
    uint48 nextMidnight = currentMidnight + TEST_BATCH_PERIOD;
    return nextMidnight;
  }

  function _lastFinalizedBatchTimestamp(address eolVault) internal view returns (uint48) {
    return _roundUpToMidnight(IERC6372(eolVault).clock()) - TEST_BATCH_PERIOD;
  }

  function _claimableAmountForBatch(
    StorageV1 storage $,
    address eolVault,
    address account,
    address reward,
    uint48 batchTimestamp
  ) internal view returns (uint256) {
    uint48 lastFinalizedBatchTimestamp = _lastFinalizedBatchTimestamp(eolVault);
    if (batchTimestamp > lastFinalizedBatchTimestamp) return 0; // not finalized yet

    uint48 lastClaimedBatchTimestamp = _assetRewards($, eolVault, reward).lastClaimedBatchTimestamps[account];
    if (batchTimestamp <= lastClaimedBatchTimestamp) return 0; // already claimed

    return _calculateUserReward($, eolVault, account, reward, batchTimestamp);
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

    uint256 userTWAB = criteria.getTWABByTimestampRange(account, startsAt, endsAt);
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
