// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../interfaces/hub/core/IValidatorRewardDistributor.sol';
import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/// @title ValidatorRewardDistributor Storage Contract
/// @notice Storage contract for ValidatorRewardDistributor that uses ERC-7201 namespaced storage pattern
contract ValidatorRewardDistributorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IValidatorManager validatorManager;
    mapping(uint96 epoch => mapping(address valAddr => uint256 amount)) rewards;
    mapping(address staker => mapping(address valAddr => uint96)) lastClaimedEpoch;
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

  // Events
  event RewardsReported(address indexed valAddr, uint256 amount, uint96 epoch);
  event RewardsClaimed(
    address indexed staker, address indexed valAddr, uint256 amount, uint96 fromEpoch, uint96 toEpoch
  );
  event EpochFeederSet(address indexed epochFeeder);
  event ValidatorManagerSet(address indexed validatorManager);

  // Custom errors
  error NotValidator();
  error NoRewardsToClaim();
  error ArrayLengthMismatch();
  error InvalidClaimEpochRange();

  // Address of the governance MITO token contract
  address private immutable govMITO;

  // Maximum number of epochs that can be claimed at once
  // Set to 32 based on gas cost analysis and typical usage patterns
  uint256 public constant MAX_CLAIM_EPOCHS = 32;

  /// @notice Contract constructor
  /// @param govMITO_ Address of the governance MITO token contract
  constructor(address govMITO_) {
    require(govMITO_.code.length > 0, StdError.InvalidAddress('govMITO'));
    govMITO = govMITO_;
    _disableInitializers();
  }

  /// @notice Initializes the contract
  /// @param initialOwner_ Address of the initial contract owner
  /// @param epochFeeder_ Address of the epoch feeder contract
  /// @param validatorManager_ Address of the validator manager contract
  function initialize(address initialOwner_, address epochFeeder_, address validatorManager_) external initializer {
    __Ownable_init(initialOwner_);
    _setEpochFeeder(epochFeeder_);
    _setValidatorManager(validatorManager_);
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
  function rewards(uint96 epoch, address valAddr) external view returns (uint256) {
    return _getStorageV1().rewards[epoch][valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function lastClaimedEpoch(address staker, address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch[staker][valAddr];
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableRewards(address valAddr, address staker) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    require($.validatorManager.isValidator(valAddr), NotValidator());

    return _claimableRewards($, valAddr, staker);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimableRewards(address[] memory valAddrs, address staker) external view returns (uint256) {
    require(staker != address(0), StdError.ZeroAddress('staker'));

    StorageV1 storage $ = _getStorageV1();

    uint256 totalClaimable;
    unchecked {
      // Gas optimization: Use unchecked since validators array length is bounded
      for (uint256 i = 0; i < valAddrs.length; i++) {
        require($.validatorManager.isValidator(valAddrs[i]), NotValidator());
        totalClaimable += _claimableRewards($, valAddrs[i], staker);
      }
    }

    return totalClaimable;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimRewards(address valAddr) external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    require($.validatorManager.isValidator(valAddr), NotValidator());

    uint256 totalClaimable = _claimRewards($, valAddr, MAX_CLAIM_EPOCHS);
    if (totalClaimable == 0) revert NoRewardsToClaim();

    IGovMITO(payable(govMITO)).safeTransfer(_msgSender(), totalClaimable);
    return totalClaimable;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function claimRewards(address[] calldata valAddrs) external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    uint256 totalClaimable;
    unchecked {
      // Gas optimization: Use unchecked since validators array length is bounded
      for (uint256 i = 0; i < valAddrs.length; i++) {
        require($.validatorManager.isValidator(valAddrs[i]), NotValidator());
        totalClaimable += _claimRewards($, valAddrs[i], MAX_CLAIM_EPOCHS);
      }
    }
    if (totalClaimable == 0) revert NoRewardsToClaim();

    IGovMITO(payable(govMITO)).safeTransfer(_msgSender(), totalClaimable);
    return totalClaimable;
  }

  /// @inheritdoc IValidatorRewardDistributor
  function reportRewards(address valAddr, uint256 amount) external onlyOwner {
    require(amount > 0, StdError.ZeroAmount());

    StorageV1 storage $ = _getStorageV1();
    require($.validatorManager.isValidator(valAddr), NotValidator());

    uint96 epoch = $.epochFeeder.epoch();
    $.rewards[epoch][valAddr] += amount;

    IGovMITO(payable(govMITO)).safeTransferFrom(_msgSender(), address(this), amount);
    emit RewardsReported(valAddr, amount, epoch);
  }

  /// @inheritdoc IValidatorRewardDistributor
  function reportRewards(address[] calldata valAddrs, uint256[] calldata amounts) external onlyOwner {
    if (valAddrs.length != amounts.length) revert ArrayLengthMismatch();
    StorageV1 storage $ = _getStorageV1();
    uint96 epoch = $.epochFeeder.epoch();
    uint256 totalAmount;

    for (uint256 i = 0; i < valAddrs.length; i++) {
      require(amounts[i] > 0, StdError.ZeroAmount());
      require($.validatorManager.isValidator(valAddrs[i]), NotValidator());

      $.rewards[epoch][valAddrs[i]] += amounts[i];
      totalAmount += amounts[i];
      emit RewardsReported(valAddrs[i], amounts[i], epoch);
    }

    IGovMITO(payable(govMITO)).safeTransferFrom(_msgSender(), address(this), totalAmount);
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

  /// @notice Internal function to set the epoch feeder contract
  /// @param epochFeeder_ Address of the new epoch feeder contract
  function _setEpochFeeder(address epochFeeder_) internal {
    require(epochFeeder_.code.length > 0, StdError.InvalidAddress('epochFeeder'));
    _getStorageV1().epochFeeder = IEpochFeeder(epochFeeder_);
  }

  /// @notice Internal function to set the validator manager contract
  /// @param validatorManager_ Address of the new validator manager contract
  function _setValidatorManager(address validatorManager_) internal {
    require(validatorManager_.code.length > 0, StdError.InvalidAddress('validatorManager'));
    _getStorageV1().validatorManager = IValidatorManager(validatorManager_);
  }

  /// @notice Calculates the total claimable rewards for a validator and staker
  /// @param $ Storage pointer
  /// @param valAddr Validator address
  /// @param staker Staker address
  /// @return Total claimable rewards
  function _claimableRewards(StorageV1 storage $, address valAddr, address staker) internal view returns (uint256) {
    uint256 totalClaimable;
    (uint96 start, uint96 end) = _claimRange($, staker, valAddr, $.epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    for (uint96 epoch = start; epoch < end; epoch++) {
      totalClaimable += _claimRewardForEpoch($, valAddr, staker, epoch);
    }

    return totalClaimable;
  }

  /// @notice Calculates the valid epoch range for claiming rewards
  /// @param $ Storage pointer
  /// @param staker Staker address
  /// @param valAddr Validator address
  /// @param currentEpoch Current epoch
  /// @param epochCount Maximum number of epochs to claim
  /// @return startEpoch Start epoch for claiming
  /// @return endEpoch End epoch for claiming
  function _claimRange(StorageV1 storage $, address staker, address valAddr, uint96 currentEpoch, uint256 epochCount)
    internal
    view
    returns (uint96, uint96)
  {
    uint96 startEpoch = $.lastClaimedEpoch[staker][valAddr];
    startEpoch = startEpoch == 0 ? 1 : startEpoch; // min epoch is 1
    // do not claim rewards for current epoch
    uint96 endEpoch = (Math.min(currentEpoch, startEpoch + epochCount - 1)).toUint96();

    return (startEpoch, endEpoch);
  }

  /// @notice Claims rewards for a validator over a range of epochs
  /// @param $ Storage pointer
  /// @param valAddr Validator address
  /// @param epochCount Maximum number of epochs to claim
  /// @return Total claimed rewards
  function _claimRewards(StorageV1 storage $, address valAddr, uint256 epochCount) internal returns (uint256) {
    uint256 totalClaimable;
    (uint96 start, uint96 end) = _claimRange($, _msgSender(), valAddr, $.epochFeeder.epoch(), epochCount);
    if (start == end) return 0;

    for (uint96 epoch = start; epoch < end; epoch++) {
      totalClaimable += _claimRewardForEpoch($, valAddr, _msgSender(), epoch);
    }

    $.lastClaimedEpoch[_msgSender()][valAddr] = end;
    return totalClaimable;
  }

  /// @notice Calculates the reward amount for a specific epoch
  /// @dev stakerRewardPerEpoch = TWAB(delegation[epoch] / totalSupply[epoch]) * rewards
  /// @param $ Storage pointer
  /// @param valAddr Validator address
  /// @param staker Staker address
  /// @param epoch Epoch number
  /// @return Reward amount for the epoch
  function _claimRewardForEpoch(StorageV1 storage $, address valAddr, address staker, uint96 epoch)
    internal
    view
    returns (uint256)
  {
    uint256 rewards_ = $.rewards[epoch][valAddr];
    if (rewards_ == 0) return 0;

    uint48 epochTime = $.epochFeeder.epochToTime(epoch);
    uint48 nextEpochTime = $.epochFeeder.epochToTime(epoch + 1) - 1; // -1 to avoid double counting

    uint256 totalDelegation;
    uint256 stakerDelegation;
    {
      uint256 startTWAB = $.validatorManager.totalDelegationTWAB(valAddr, epochTime);
      uint256 endTWAB = $.validatorManager.totalDelegationTWAB(valAddr, nextEpochTime);
      totalDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }
    {
      uint256 startTWAB = $.validatorManager.stakedTWAB(valAddr, staker, epochTime);
      uint256 endTWAB = $.validatorManager.stakedTWAB(valAddr, staker, nextEpochTime);
      stakerDelegation = (endTWAB - startTWAB) * 1e18 / (nextEpochTime - epochTime) / 1e18;
    }

    if (totalDelegation == 0) return 0;
    uint256 claimable = (stakerDelegation * rewards_) / totalDelegation;

    return claimable;
  }

  // ====================== UUPS ======================

  /// @notice Authorizes an upgrade to a new implementation
  /// @param newImplementation Address of the new implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
