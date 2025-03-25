// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { ReentrancyGuardTransient } from '@oz-v5/utils/ReentrancyGuardTransient.sol';

import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../interfaces/hub/IGovMITOEmission.sol';
import { IEpochFeeder } from '../../interfaces/hub/validator/IEpochFeeder.sol';
import {
  IValidatorContributionFeed, ValidatorWeight
} from '../../interfaces/hub/validator/IValidatorContributionFeed.sol';
import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../interfaces/hub/validator/IValidatorRewardDistributor.sol';
import { IValidatorStakingHub } from '../../interfaces/hub/validator/IValidatorStakingHub.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/// @title ValidatorRewardDistributor Storage Contract
/// @notice Storage contract for ValidatorRewardDistributor that uses ERC-7201 namespaced storage pattern
contract ValidatorRewardDistributorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    // Approvals
    mapping(address account => mapping(address valAddr => mapping(address claimer => bool))) stakerClaimApprovals;
    mapping(address account => mapping(address valAddr => mapping(address claimer => bool))) operatorClaimApprovals;
    // LastClaimedEpochs
    mapping(address staker => mapping(address valAddr => uint256)) staker;
    mapping(address valAddr => uint256) operator;
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
  ReentrancyGuardTransient,
  UUPSUpgradeable
{
  using SafeCast for uint256;
  using SafeERC20 for IGovMITO;

  IEpochFeeder private immutable _epochFeeder;
  IValidatorManager private immutable _validatorManager;
  IValidatorStakingHub private immutable _validatorStakingHub;
  IValidatorContributionFeed private immutable _validatorContributionFeed;
  IGovMITOEmission private immutable _govMITOEmission;

  // Maximum number of epochs that can be claimed at once
  // Set to 32 based on gas cost analysis and typical usage patterns
  uint256 public constant MAX_CLAIM_EPOCHS = 32;

  // Maximum number of stakers that can be claimed at once
  uint256 public constant MAX_STAKER_BATCH_SIZE = 100;

  // Maximum number of operators that can be claimed at once
  uint256 public constant MAX_OPERATOR_BATCH_SIZE = 100;

  constructor(
    address epochFeeder_,
    address validatorManager_,
    address validatorStakingHub_,
    address validatorContributionFeed_,
    address govMITOEmission_
  ) {
    _disableInitializers();

    _epochFeeder = IEpochFeeder(epochFeeder_);
    _validatorManager = IValidatorManager(validatorManager_);
    _validatorStakingHub = IValidatorStakingHub(validatorStakingHub_);
    _validatorContributionFeed = IValidatorContributionFeed(validatorContributionFeed_);
    _govMITOEmission = IGovMITOEmission(govMITOEmission_);
  }

  function initialize(address initialOwner_) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner_);
    __Ownable2Step_init();
  }

  /// @inheritdoc IValidatorRewardDistributor
  function epochFeeder() external view returns (IEpochFeeder) {
    return _epochFeeder;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function validatorManager() external view returns (IValidatorManager) {
    return _validatorManager;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function validatorContributionFeed() external view returns (IValidatorContributionFeed) {
    return _validatorContributionFeed;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function validatorStakingHub() external view returns (IValidatorStakingHub) {
    return _validatorStakingHub;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function govMITOEmission() external view returns (IGovMITOEmission) {
    return _govMITOEmission;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function stakerClaimAllowed(address account, address valAddr, address claimer) external view returns (bool) {
    return _isClaimable(account, valAddr, claimer, _getStorageV1().stakerClaimApprovals);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function operatorClaimAllowed(address account, address valAddr, address claimer) external view returns (bool) {
    return _isClaimable(account, valAddr, claimer, _getStorageV1().operatorClaimApprovals);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedStakerRewardsEpoch(address staker, address valAddr) external view returns (uint256) {
    return _getStorageV1().staker[staker][valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedOperatorRewardsEpoch(address valAddr) external view returns (uint256) {
    return _getStorageV1().operator[valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableStakerRewards(address staker, address valAddr) external view returns (uint256, uint256) {
    return _claimableStakerRewards(_getStorageV1(), valAddr, staker, MAX_CLAIM_EPOCHS);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableOperatorRewards(address valAddr) external view returns (uint256, uint256) {
    return _claimableOperatorRewards(_getStorageV1(), valAddr, MAX_CLAIM_EPOCHS);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function setStakerClaimApprovalStatus(address valAddr, address claimer, bool approval) external {
    _getStorageV1().stakerClaimApprovals[_msgSender()][valAddr][claimer] = approval;
    emit StakerRewardClaimApprovalUpdated(_msgSender(), valAddr, claimer, approval);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function setOperatorClaimApprovalStatus(address valAddr, address claimer, bool approval) external {
    _getStorageV1().operatorClaimApprovals[_msgSender()][valAddr][claimer] = approval;
    emit OperatorRewardClaimApprovalUpdated(_msgSender(), valAddr, claimer, approval);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimStakerRewards(address staker, address valAddr) external nonReentrant returns (uint256) {
    return _claimStakerRewards(_getStorageV1(), staker, valAddr, _msgSender());
  }

  /// @inheritdoc IValidatorRewardDistributor
  function batchClaimStakerRewards(address[] calldata stakers, address[][] calldata valAddrs)
    external
    nonReentrant
    returns (uint256)
  {
    require(stakers.length <= MAX_STAKER_BATCH_SIZE, IValidatorRewardDistributor__MaxStakerBatchSizeExceeded());
    require(stakers.length == valAddrs.length, IValidatorRewardDistributor__ArrayLengthMismatch());

    uint256 totalClaimed;
    for (uint256 i = 0; i < stakers.length; i++) {
      for (uint256 j = 0; j < valAddrs[i].length; j++) {
        totalClaimed += _claimStakerRewards(_getStorageV1(), stakers[i], valAddrs[i][j], _msgSender());
      }
    }

    return totalClaimed;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimOperatorRewards(address valAddr) external nonReentrant returns (uint256) {
    return _claimOperatorRewards(_getStorageV1(), valAddr, _msgSender());
  }

  /// @inheritdoc IValidatorRewardDistributor
  function batchClaimOperatorRewards(address[] calldata valAddrs) external nonReentrant returns (uint256) {
    require(valAddrs.length <= MAX_OPERATOR_BATCH_SIZE, IValidatorRewardDistributor__MaxOperatorBatchSizeExceeded());

    uint256 totalClaimed;

    for (uint256 i = 0; i < valAddrs.length; i++) {
      totalClaimed += _claimOperatorRewards(_getStorageV1(), valAddrs[i], _msgSender());
    }

    return totalClaimed;
  }

  function _claimableStakerRewards(StorageV1 storage $, address valAddr, address staker, uint256 epochCount)
    internal
    view
    returns (uint256, uint256)
  {
    (uint256 start, uint256 end) = _claimRange($.staker[staker][valAddr], _epochFeeder.epoch(), epochCount);
    if (start == end) return (0, start);

    uint256 totalClaimable;

    for (uint256 epoch = start; epoch <= end; epoch++) {
      if (!_validatorContributionFeed.available(epoch)) return (totalClaimable, epoch);
      totalClaimable += _calculateStakerRewardForEpoch(valAddr, staker, epoch);
    }

    return (totalClaimable, end + 1);
  }

  function _claimableOperatorRewards(StorageV1 storage $, address valAddr, uint256 epochCount)
    internal
    view
    returns (uint256, uint256)
  {
    (uint256 start, uint256 end) = _claimRange($.operator[valAddr], _epochFeeder.epoch(), epochCount);
    if (start == end) return (0, start);

    uint256 totalOperatorReward;

    for (uint256 epoch = start; epoch <= end; epoch++) {
      if (!_validatorContributionFeed.available(epoch)) return (totalOperatorReward, epoch);
      (uint256 operatorReward,) = _rewardForEpoch(valAddr, epoch);
      totalOperatorReward += operatorReward;
    }

    return (totalOperatorReward, end + 1);
  }

  function _claimStakerRewards(StorageV1 storage $, address staker, address valAddr, address recipient)
    internal
    returns (uint256)
  {
    _assertClaimApproval(staker, valAddr, recipient, $.stakerClaimApprovals);

    (uint256 start, uint256 end) = _claimRange($.staker[staker][valAddr], _epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    uint256 totalClaimed;
    uint256 lastClaimedEpoch = start - 1;

    for (uint256 epoch = start; epoch <= end; epoch++) {
      if (!_validatorContributionFeed.available(epoch)) break;

      uint256 claimable = _calculateStakerRewardForEpoch(valAddr, staker, epoch);

      if (claimable > 0) {
        _govMITOEmission.requestValidatorReward(epoch.toUint96(), staker, claimable);
        totalClaimed += claimable;
      }

      lastClaimedEpoch = epoch;
    }

    $.staker[staker][valAddr] = lastClaimedEpoch;

    emit StakerRewardsClaimed(staker, valAddr, recipient, totalClaimed, start, lastClaimedEpoch);

    return totalClaimed;
  }

  function _claimOperatorRewards(StorageV1 storage $, address valAddr, address recipient) internal returns (uint256) {
    _assertClaimApproval(
      _validatorManager.validatorInfo(valAddr).rewardManager, valAddr, recipient, $.operatorClaimApprovals
    );

    (uint256 start, uint256 end) = _claimRange($.operator[valAddr], _epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    uint256 totalClaimed;
    uint256 lastClaimedEpoch = start - 1;

    for (uint256 epoch = start; epoch <= end; epoch++) {
      if (!_validatorContributionFeed.available(epoch)) break;
      (uint256 claimable,) = _rewardForEpoch(valAddr, epoch);

      // NOTE(eddy): reentrancy guard?
      if (claimable > 0) {
        _govMITOEmission.requestValidatorReward(epoch.toUint96(), recipient, claimable);
        totalClaimed += claimable;
      }

      lastClaimedEpoch = epoch;
    }

    $.operator[valAddr] = lastClaimedEpoch;

    emit OperatorRewardsClaimed(valAddr, recipient, totalClaimed, start, lastClaimedEpoch);

    return totalClaimed;
  }

  function _claimRange(uint256 lastClaimedEpoch, uint256 currentEpoch, uint256 epochCount)
    internal
    pure
    returns (uint256, uint256)
  {
    uint256 startEpoch = lastClaimedEpoch + 1; // min epoch is 1
    // do not claim rewards for current epoch
    uint256 endEpoch = (Math.min(currentEpoch, startEpoch + epochCount - 1)).toUint96();
    return (startEpoch, endEpoch);
  }

  function _calculateStakerRewardForEpoch(address valAddr, address staker, uint256 epoch)
    internal
    view
    returns (uint256)
  {
    (, uint256 stakerReward) = _rewardForEpoch(valAddr, epoch);
    if (stakerReward == 0) return 0;

    uint48 epochTime = _epochFeeder.timeAt(epoch);
    uint48 nextEpochTime = _epochFeeder.timeAt(epoch + 1) - 1; // -1 to avoid double counting

    uint256 totalDelegation;
    uint256 stakerDelegation;
    {
      uint256 startTWAB = _validatorStakingHub.validatorTotalTWAB(valAddr, epochTime);
      uint256 endTWAB = _validatorStakingHub.validatorTotalTWAB(valAddr, nextEpochTime);
      totalDelegation = Math.mulDiv(endTWAB - startTWAB, 1e18, nextEpochTime - epochTime);
    }
    {
      uint256 startTWAB = _validatorStakingHub.validatorStakerTotalTWAB(valAddr, staker, epochTime);
      uint256 endTWAB = _validatorStakingHub.validatorStakerTotalTWAB(valAddr, staker, nextEpochTime);
      stakerDelegation = Math.mulDiv(endTWAB - startTWAB, 1e18, nextEpochTime - epochTime);
    }

    if (totalDelegation == 0) return 0;
    uint256 claimable = (stakerDelegation * stakerReward) / totalDelegation;

    return claimable;
  }

  /// @return operatorReward The amount of operator reward for the epoch
  /// @return stakerReward The amount of staker reward for the epoch
  function _rewardForEpoch(address valAddr, uint256 epoch) internal view returns (uint256, uint256) {
    IValidatorManager.ValidatorInfoResponse memory validatorInfo = _validatorManager.validatorInfoAt(epoch, valAddr);
    IValidatorContributionFeed.Summary memory rewardSummary = _validatorContributionFeed.summary(epoch);
    (ValidatorWeight memory weight, bool exists) = _validatorContributionFeed.weightOf(epoch, valAddr);
    if (!exists) return (0, 0);

    uint256 totalReward =
      (_govMITOEmission.validatorReward(epoch.toUint96()) * weight.weight) / rewardSummary.totalWeight;
    uint256 totalRewardShare = weight.collateralRewardShare + weight.delegationRewardShare;

    uint256 stakerReward = (totalReward * weight.delegationRewardShare) / totalRewardShare;
    uint256 commission = (stakerReward * validatorInfo.commissionRate) / _validatorManager.MAX_COMMISSION_RATE();

    return ((totalReward - stakerReward) + commission, stakerReward - commission);
  }

  function _assertClaimApproval(
    address account,
    address valAddr,
    address recipient,
    mapping(address => mapping(address => mapping(address => bool))) storage claimApprovals
  ) internal view {
    require(_isClaimable(account, valAddr, recipient, claimApprovals), StdError.Unauthorized());
  }

  function _isClaimable(
    address account,
    address valAddr,
    address recipient,
    mapping(address => mapping(address => mapping(address => bool))) storage claimApprovals
  ) internal view returns (bool) {
    return account == recipient || claimApprovals[account][valAddr][recipient];
  }

  // ====================== UUPS ======================

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
