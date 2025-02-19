// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  IValidatorContributionFeedNotifier,
  ValidatorWeight
} from '../../interfaces/hub/core/IValidatorContributionFeed.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../interfaces/hub/core/IValidatorRewardDistributor.sol';
import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { IGovMITOCommission } from '../../interfaces/hub/IGovMITOCommission.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/// @title ValidatorRewardDistributor Storage Contract
/// @notice Storage contract for ValidatorRewardDistributor that uses ERC-7201 namespaced storage pattern
contract ValidatorRewardDistributorStorageV1 {
  using ERC7201Utils for string;

  struct LastClaimedEpoch {
    mapping(address staker => mapping(address valAddr => uint96)) staker;
    mapping(address valAddr => uint96) commission;
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IValidatorManager validatorManager;
    IValidatorContributionFeed validatorContributionFeed;
    IGovMITOCommission govMITOCommission;
    LastClaimedEpoch lastClaimedEpoch;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorRewardDistributorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    assembly {
      $.slot := slot
    }
  }
}

/// @title Validator Reward Distributor
/// @notice Handles the distribution of rewards to validators and their stakers
/// @dev Implements reward distribution logic with time-weighted average balance (TWAB) calculations
contract ValidatorRewardDistributor is
  IValidatorRewardDistributor,
  ValidatorRewardDistributorStorageV1,
  Ownable2StepUpgradeable,
  UUPSUpgradeable
{
  using SafeCast for uint256;
  using SafeERC20 for IGovMITO;

  // Address of the governance MITO token contract
  address private immutable _govMITO;

  // Maximum number of epochs that can be claimed at once
  // Set to 32 based on gas cost analysis and typical usage patterns
  uint96 public constant MAX_CLAIM_EPOCHS = 32;

  constructor(address govMITO_) {
    require(govMITO_.code.length > 0, StdError.InvalidAddress('govMITO'));
    _govMITO = govMITO_;
    _disableInitializers();
  }

  function initialize(
    address initialOwner_,
    address epochFeeder_,
    address validatorManager_,
    address validatorContributionFeed_,
    address govMITOCommission_
  ) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner_);
    __Ownable2Step_init();

    _setEpochFeeder(epochFeeder_);
    _setValidatorManager(validatorManager_);
    _setValidatorContributionFeed(validatorContributionFeed_);
    _setGovMITOCommission(govMITOCommission_);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function govMITO() external view returns (IGovMITO) {
    return IGovMITO(payable(_govMITO));
  }

  /// @inheritdoc IValidatorRewardDistributor
  function epochFeeder() external view returns (IEpochFeeder) {
    return _getStorageV1().epochFeeder;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function validatorManager() external view returns (IValidatorManager) {
    return _getStorageV1().validatorManager;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function validatorContributionFeed() external view returns (IValidatorContributionFeed) {
    return _getStorageV1().validatorContributionFeed;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function govMITOCommission() external view returns (IGovMITOCommission) {
    return _getStorageV1().govMITOCommission;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedCommissionEpoch(address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch.commission[valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedStakerRewardsEpoch(address staker, address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch.staker[staker][valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableRewards(address staker) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    address[] memory valAddrs = $.validatorManager.stakedValidators(staker);
    if (valAddrs.length == 0) return 0;

    uint256 totalClaimable;
    unchecked {
      // Gas optimization: Use unchecked since validators array length is bounded
      for (uint256 i = 0; i < valAddrs.length; i++) {
        (uint256 claimable,) = _claimableRewards($, valAddrs[i], staker, MAX_CLAIM_EPOCHS);
        totalClaimable += claimable;
      }
    }

    return totalClaimable;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableCommission(address valAddr) external view returns (uint256) {
    (uint256 commission,) = _claimableCommission(_getStorageV1(), valAddr, MAX_CLAIM_EPOCHS);
    return commission;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimRewards() external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    address[] memory valAddrs = $.validatorManager.stakedValidators(_msgSender());
    require(valAddrs.length == 0, NoStakedValidators());

    uint256 totalClaimable;
    unchecked {
      // Gas optimization: Use unchecked since validators array length is bounded
      for (uint256 i = 0; i < valAddrs.length; i++) {
        (uint256 claimable, uint96 nextEpoch) = _claimableRewards($, valAddrs[i], _msgSender(), MAX_CLAIM_EPOCHS);
        if (claimable == 0) continue;

        $.lastClaimedEpoch.staker[_msgSender()][valAddrs[i]] = nextEpoch;
        totalClaimable += claimable;
      }
    }
    require(totalClaimable > 0, NoRewardsToClaim());

    IGovMITO(payable(_govMITO)).safeTransfer(_msgSender(), totalClaimable);
    return totalClaimable;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimCommission(address valAddr) external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    IValidatorManager.ValidatorInfoResponse memory validatorInfo = $.validatorManager.validatorInfo(valAddr);
    require(validatorInfo.rewardRecipient == _msgSender(), NotRewardRecipient());

    (uint256 commission, uint96 nextEpoch) = _claimableCommission($, valAddr, MAX_CLAIM_EPOCHS);
    require(commission > 0, NoCommissionToClaim());

    $.lastClaimedEpoch.commission[valAddr] = nextEpoch;

    IGovMITO(payable(_govMITO)).safeTransfer(validatorInfo.rewardRecipient, commission);
    return commission;
  }

  function notifyReportFinalized(uint96 epoch) external {
    StorageV1 storage $ = _getStorageV1();
    IValidatorContributionFeed feed = $.validatorContributionFeed;
    require(address(feed) == _msgSender(), StdError.Unauthorized());

    IValidatorContributionFeed.Summary memory summary = feed.summary(epoch);

    $.govMITOCommission.request(summary.totalReward);
  }

  /// @notice Sets a new epoch feeder contract
  /// @param epochFeeder_ Address of the new epoch feeder contract
  function setEpochFeeder(address epochFeeder_) external onlyOwner {
    _setEpochFeeder(epochFeeder_);
  }

  /// @notice Sets a new validator manager contract
  /// @param validatorManager_ Address of the new validator manager contract
  function setValidatorManager(address validatorManager_) external onlyOwner {
    _setValidatorManager(validatorManager_);
  }

  /// @notice Sets a new validator reward feed contract
  /// @param validatorContributionFeed_ Address of the new validator reward feed contract
  function setValidatorContributionFeed(address validatorContributionFeed_) external onlyOwner {
    _setValidatorContributionFeed(validatorContributionFeed_);
  }

  /// @notice Sets a new GovMITO commission contract
  /// @param govMITOCommission_ Address of the new GovMITO commission contract
  function setGovMITOCommission(address govMITOCommission_) external onlyOwner {
    _setGovMITOCommission(govMITOCommission_);
  }

  function _setEpochFeeder(address epochFeeder_) internal {
    require(epochFeeder_.code.length > 0, StdError.InvalidAddress('epochFeeder'));
    _getStorageV1().epochFeeder = IEpochFeeder(epochFeeder_);
  }

  function _setValidatorManager(address validatorManager_) internal {
    require(validatorManager_.code.length > 0, StdError.InvalidAddress('validatorManager'));
    _getStorageV1().validatorManager = IValidatorManager(validatorManager_);
  }

  function _setValidatorContributionFeed(address validatorContributionFeed_) internal {
    require(validatorContributionFeed_.code.length > 0, StdError.InvalidAddress('validatorContributionFeed'));
    _getStorageV1().validatorContributionFeed = IValidatorContributionFeed(validatorContributionFeed_);
  }

  function _setGovMITOCommission(address govMITOCommission_) internal {
    require(govMITOCommission_.code.length > 0, StdError.InvalidAddress('govMITOCommission'));
    _getStorageV1().govMITOCommission = IGovMITOCommission(govMITOCommission_);
  }

  function _claimableRewards(StorageV1 storage $, address valAddr, address staker, uint96 epochCount)
    internal
    view
    returns (uint256, uint96)
  {
    (uint96 start, uint96 end) =
      _claimRange($.lastClaimedEpoch.staker[staker][valAddr], $.epochFeeder.epoch(), epochCount);
    if (start == end) return (0, 0);

    uint256 totalClaimable;

    for (uint96 epoch = start; epoch < end; epoch++) {
      if (!$.validatorContributionFeed.available(epoch)) break;
      totalClaimable += _claimRewardForEpoch($, valAddr, staker, epoch);
    }

    return (totalClaimable, end);
  }

  function _claimableCommission(StorageV1 storage $, address valAddr, uint96 epochCount)
    internal
    view
    returns (uint256, uint96)
  {
    (uint96 start, uint96 end) = _claimRange($.lastClaimedEpoch.commission[valAddr], $.epochFeeder.epoch(), epochCount);
    if (start == end) return (0, 0);

    uint256 totalCommission;

    for (uint96 epoch = start; epoch < end; epoch++) {
      if (!$.validatorContributionFeed.available(epoch)) break;
      (uint256 commission,) = _validatorRewardForEpoch($, valAddr, epoch);
      totalCommission += commission;
    }

    return (totalCommission, end);
  }

  function _claimRange(uint96 lastClaimedEpoch, uint96 currentEpoch, uint256 epochCount)
    internal
    pure
    returns (uint96, uint96)
  {
    uint96 startEpoch = lastClaimedEpoch;
    startEpoch = startEpoch == 0 ? 1 : startEpoch; // min epoch is 1
    // do not claim rewards for current epoch
    uint96 endEpoch = (Math.min(currentEpoch, startEpoch + epochCount - 1)).toUint96();

    return (startEpoch, endEpoch);
  }

  function _claimRewards(StorageV1 storage $, address valAddr, address staker, uint256 epochCount)
    internal
    returns (uint256)
  {
    uint96 lastClaimedEpoch = $.lastClaimedEpoch.staker[staker][valAddr];
    (uint96 start, uint96 end) = _claimRange(lastClaimedEpoch, $.epochFeeder.epoch(), epochCount);
    if (start == end) return 0;

    uint256 totalClaimable;

    for (uint96 epoch = start; epoch < end; epoch++) {
      totalClaimable += _claimRewardForEpoch($, valAddr, staker, epoch);
    }

    $.lastClaimedEpoch.staker[staker][valAddr] = end;
    return totalClaimable;
  }

  function _claimCommission(StorageV1 storage $, address valAddr, uint256 epochCount) internal view returns (uint256) {
    uint96 lastClaimedEpoch = $.lastClaimedEpoch.commission[valAddr];
    (uint96 start, uint96 end) = _claimRange(lastClaimedEpoch, $.epochFeeder.epoch(), epochCount);
    if (start == end) return 0;

    uint256 totalCommission;

    for (uint96 epoch = start; epoch < end; epoch++) {
      (uint256 commission,) = _validatorRewardForEpoch($, valAddr, epoch);
      totalCommission += commission;
    }

    return totalCommission;
  }

  function _claimRewardForEpoch(StorageV1 storage $, address valAddr, address staker, uint96 epoch)
    internal
    view
    returns (uint256)
  {
    (, uint256 stakerReward) = _validatorRewardForEpoch($, valAddr, epoch);
    if (stakerReward == 0) return 0;

    uint48 epochTime = $.epochFeeder.epochToTime(epoch);
    uint48 nextEpochTime = $.epochFeeder.epochToTime(epoch + 1) - 1; // -1 to avoid double counting

    uint256 totalDelegation;
    uint256 stakerDelegation;
    {
      uint256 startTWAB = $.validatorManager.totalDelegationTWABAt(valAddr, epochTime);
      uint256 endTWAB = $.validatorManager.totalDelegationTWABAt(valAddr, nextEpochTime);
      totalDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }
    {
      uint256 startTWAB = $.validatorManager.stakedTWABAt(valAddr, staker, epochTime);
      uint256 endTWAB = $.validatorManager.stakedTWABAt(valAddr, staker, nextEpochTime);
      stakerDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }

    if (totalDelegation == 0) return 0;
    uint256 claimable = (stakerDelegation * stakerReward) / totalDelegation;

    return claimable;
  }

  function _validatorRewardForEpoch(StorageV1 storage $, address valAddr, uint96 epoch)
    internal
    view
    returns (uint256, uint256)
  {
    IValidatorManager.ValidatorInfoResponse memory validatorInfo = $.validatorManager.validatorInfoAt(epoch, valAddr);
    IValidatorContributionFeed.Summary memory rewardSummary = $.validatorContributionFeed.summary(epoch);
    (ValidatorWeight memory weight, bool exists) = $.validatorContributionFeed.weightOf(epoch, valAddr);
    if (!exists) return (0, 0);

    uint256 totalReward = (rewardSummary.totalReward * weight.weight) / rewardSummary.totalWeight;
    uint256 commission = (totalReward * validatorInfo.commissionRate) / $.validatorManager.MAX_COMMISSION_RATE();

    return (commission, totalReward - commission);
  }

  // ====================== UUPS ======================

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
