// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../interfaces/hub/IGovMITOEmission.sol';
import { IEpochFeeder } from '../../interfaces/hub/validator/IEpochFeeder.sol';
import {
  IValidatorContributionFeed, ValidatorWeight
} from '../../interfaces/hub/validator/IValidatorContributionFeed.sol';
import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../interfaces/hub/validator/IValidatorRewardDistributor.sol';
import { IValidatorStaking } from '../../interfaces/hub/validator/IValidatorStaking.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/// @title ValidatorRewardDistributor Storage Contract
/// @notice Storage contract for ValidatorRewardDistributor that uses ERC-7201 namespaced storage pattern
contract ValidatorRewardDistributorStorageV1 {
  using ERC7201Utils for string;

  struct LastClaimedEpoch {
    mapping(address staker => mapping(address valAddr => uint96)) staker;
    mapping(address valAddr => uint96) operator;
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IValidatorManager validatorManager;
    IValidatorStaking validatorStaking;
    IValidatorContributionFeed validatorContributionFeed;
    IGovMITOEmission govMITOEmission;
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

  // Maximum number of epochs that can be claimed at once
  // Set to 32 based on gas cost analysis and typical usage patterns
  uint96 public constant MAX_CLAIM_EPOCHS = 32;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address initialOwner_,
    address epochFeeder_,
    address validatorManager_,
    address validatorStaking_,
    address validatorContributionFeed_,
    address govMITOEmission_
  ) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner_);
    __Ownable2Step_init();

    _setEpochFeeder(epochFeeder_);
    _setValidatorManager(validatorManager_);
    _setValidatorStaking(validatorStaking_);
    _setValidatorContributionFeed(validatorContributionFeed_);
    _setGovMITOEmission(govMITOEmission_);
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
  function validatorStaking() external view returns (IValidatorStaking) {
    return _getStorageV1().validatorStaking;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function govMITOEmission() external view returns (IGovMITOEmission) {
    return _getStorageV1().govMITOEmission;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedStakerRewardsEpoch(address staker, address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch.staker[staker][valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedOperatorRewardsEpoch(address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch.operator[valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableStakerRewards(address staker, address valAddr) external view returns (uint256, uint96) {
    return _claimableStakerRewards(_getStorageV1(), valAddr, staker, MAX_CLAIM_EPOCHS);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableOperatorRewards(address valAddr) external view returns (uint256, uint96) {
    return _claimableOperatorRewards(_getStorageV1(), valAddr, MAX_CLAIM_EPOCHS);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimStakerRewards(address staker, address valAddr) external returns (uint256) {
    return _claimStakerRewards(_getStorageV1(), staker, valAddr);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function batchClaimStakerRewards(address[] calldata stakers, address[][] calldata valAddrs)
    external
    returns (uint256)
  {
    require(stakers.length == valAddrs.length, ArrayLengthMismatch());

    uint256 totalClaimed;
    for (uint256 i = 0; i < stakers.length; i++) {
      for (uint256 j = 0; j < valAddrs[i].length; j++) {
        totalClaimed += _claimStakerRewards(_getStorageV1(), stakers[i], valAddrs[i][j]);
      }
    }

    return totalClaimed;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimOperatorRewards(address valAddr) external returns (uint256) {
    return _claimOperatorRewards(_getStorageV1(), valAddr);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function batchClaimOperatorRewards(address[] calldata valAddrs) external returns (uint256) {
    uint256 totalClaimed;

    for (uint256 i = 0; i < valAddrs.length; i++) {
      totalClaimed += _claimOperatorRewards(_getStorageV1(), valAddrs[i]);
    }

    return totalClaimed;
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

  /// @notice Sets a new validator delegation manager contract
  /// @param validatorStaking_ Address of the new validator delegation manager contract
  function setValidatorStaking(address validatorStaking_) external onlyOwner {
    _setValidatorStaking(validatorStaking_);
  }

  /// @notice Sets a new validator reward feed contract
  /// @param validatorContributionFeed_ Address of the new validator reward feed contract
  function setValidatorContributionFeed(address validatorContributionFeed_) external onlyOwner {
    _setValidatorContributionFeed(validatorContributionFeed_);
  }

  /// @notice Sets a new GovMITO emission contract
  /// @param govMITOEmission_ Address of the new GovMITO emission contract
  function setGovMITOEmission(address govMITOEmission_) external onlyOwner {
    _setGovMITOEmission(govMITOEmission_);
  }

  function _setEpochFeeder(address epochFeeder_) internal {
    require(epochFeeder_.code.length > 0, StdError.InvalidAddress('epochFeeder'));
    _getStorageV1().epochFeeder = IEpochFeeder(epochFeeder_);
  }

  function _setValidatorManager(address validatorManager_) internal {
    require(validatorManager_.code.length > 0, StdError.InvalidAddress('validatorManager'));
    _getStorageV1().validatorManager = IValidatorManager(validatorManager_);
  }

  function _setValidatorStaking(address validatorStaking_) internal {
    require(validatorStaking_.code.length > 0, StdError.InvalidAddress('validatorStaking'));
    _getStorageV1().validatorStaking = IValidatorStaking(validatorStaking_);
  }

  function _setValidatorContributionFeed(address validatorContributionFeed_) internal {
    require(validatorContributionFeed_.code.length > 0, StdError.InvalidAddress('validatorContributionFeed'));
    _getStorageV1().validatorContributionFeed = IValidatorContributionFeed(validatorContributionFeed_);
  }

  function _setGovMITOEmission(address govMITOEmission_) internal {
    require(govMITOEmission_.code.length > 0, StdError.InvalidAddress('govMITOEmission'));
    _getStorageV1().govMITOEmission = IGovMITOEmission(govMITOEmission_);
  }

  function _claimableStakerRewards(StorageV1 storage $, address valAddr, address staker, uint96 epochCount)
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
      totalClaimable += _calculateStakerRewardForEpoch($, valAddr, staker, epoch);
    }

    return (totalClaimable, end);
  }

  function _claimableOperatorRewards(StorageV1 storage $, address valAddr, uint96 epochCount)
    internal
    view
    returns (uint256, uint96)
  {
    (uint96 start, uint96 end) = _claimRange($.lastClaimedEpoch.operator[valAddr], $.epochFeeder.epoch(), epochCount);
    if (start == end) return (0, 0);

    uint256 totalOperatorReward;

    for (uint96 epoch = start; epoch < end; epoch++) {
      if (!$.validatorContributionFeed.available(epoch)) break;
      (uint256 operatorReward,) = _rewardForEpoch($, valAddr, epoch);
      totalOperatorReward += operatorReward;
    }

    return (totalOperatorReward, end);
  }

  function _claimStakerRewards(StorageV1 storage $, address staker, address valAddr) internal returns (uint256) {
    (uint96 start, uint96 end) =
      _claimRange($.lastClaimedEpoch.staker[staker][valAddr], $.epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    uint256 totalClaimed;

    for (uint96 epoch = start; epoch < end; epoch++) {
      if (!$.validatorContributionFeed.available(epoch)) break;
      uint256 claimable = _calculateStakerRewardForEpoch($, valAddr, staker, epoch);

      // NOTE(eddy): reentrancy guard?
      if (claimable > 0) $.govMITOEmission.requestValidatorReward(epoch, staker, claimable);

      totalClaimed += claimable;
    }

    $.lastClaimedEpoch.staker[staker][valAddr] = end;

    return totalClaimed;
  }

  function _claimOperatorRewards(StorageV1 storage $, address valAddr) internal returns (uint256) {
    (uint96 start, uint96 end) =
      _claimRange($.lastClaimedEpoch.operator[valAddr], $.epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    address recipient = $.validatorManager.validatorInfo(valAddr).rewardRecipient;
    uint256 totalClaimed;

    for (uint96 epoch = start; epoch < end; epoch++) {
      if (!$.validatorContributionFeed.available(epoch)) break;
      (uint256 claimable,) = _rewardForEpoch($, valAddr, epoch);

      // NOTE(eddy): reentrancy guard?
      if (claimable > 0) $.govMITOEmission.requestValidatorReward(epoch, recipient, claimable);

      totalClaimed += claimable;
    }

    $.lastClaimedEpoch.operator[valAddr] = end;

    return totalClaimed;
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

  function _calculateStakerRewardForEpoch(StorageV1 storage $, address valAddr, address staker, uint96 epoch)
    internal
    view
    returns (uint256)
  {
    (, uint256 stakerReward) = _rewardForEpoch($, valAddr, epoch);
    if (stakerReward == 0) return 0;

    uint48 epochTime = $.epochFeeder.epochToTime(epoch);
    uint48 nextEpochTime = $.epochFeeder.epochToTime(epoch + 1) - 1; // -1 to avoid double counting

    uint256 totalDelegation;
    uint256 stakerDelegation;
    {
      uint256 startTWAB = $.validatorStaking.totalDelegationTWABAt(valAddr, epochTime);
      uint256 endTWAB = $.validatorStaking.totalDelegationTWABAt(valAddr, nextEpochTime);
      totalDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }
    {
      uint256 startTWAB = $.validatorStaking.stakedTWABAt(valAddr, staker, epochTime);
      uint256 endTWAB = $.validatorStaking.stakedTWABAt(valAddr, staker, nextEpochTime);
      stakerDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }

    if (totalDelegation == 0) return 0;
    uint256 claimable = (stakerDelegation * stakerReward) / totalDelegation;

    return claimable;
  }

  /// @return operatorReward The amount of operator reward for the epoch
  /// @return stakerReward The amount of staker reward for the epoch
  function _rewardForEpoch(StorageV1 storage $, address valAddr, uint96 epoch) internal view returns (uint256, uint256) {
    IValidatorManager.ValidatorInfoResponse memory validatorInfo = $.validatorManager.validatorInfoAt(epoch, valAddr);
    IValidatorContributionFeed.Summary memory rewardSummary = $.validatorContributionFeed.summary(epoch);
    (ValidatorWeight memory weight, bool exists) = $.validatorContributionFeed.weightOf(epoch, valAddr);
    if (!exists) return (0, 0);

    uint256 totalReward;
    {
      (uint256 totalValidatorReward,) = $.govMITOEmission.validatorReward(epoch);
      totalReward = (totalValidatorReward * weight.weight) / rewardSummary.totalWeight;
    }

    uint256 totalRewardShare = weight.collateralRewardShare + weight.delegationRewardShare;
    uint256 stakerReward = (totalReward * weight.delegationRewardShare) / totalRewardShare;
    uint256 commission = (stakerReward * validatorInfo.commissionRate) / $.validatorManager.MAX_COMMISSION_RATE();

    return ((totalReward - stakerReward) + commission, stakerReward - commission);
  }

  // ====================== UUPS ======================

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
