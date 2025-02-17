// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

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

contract ValidatorRewardDistributor is ValidatorRewardDistributorStorageV1, Ownable2StepUpgradeable, UUPSUpgradeable {
  using SafeCast for uint256;
  using SafeERC20 for IGovMITO;

  address public immutable govMITO;
  uint256 public constant MAX_CLAIM_EPOCHS = 32;

  constructor(address govMITO_) {
    govMITO = govMITO_;
    _disableInitializers();
  }

  function initialize(address initialOwner_, address epochFeeder_, address validatorManager_) external initializer {
    __Ownable_init(initialOwner_);
    _setEpochFeeder(epochFeeder_);
    _setValidatorManager(validatorManager_);
  }

  function epochFeeder() external view returns (IEpochFeeder) {
    return _getStorageV1().epochFeeder;
  }

  function validatorManager() external view returns (IValidatorManager) {
    return _getStorageV1().validatorManager;
  }

  function rewards(uint96 epoch, address valAddr) external view returns (uint256) {
    return _getStorageV1().rewards[epoch][valAddr];
  }

  function lastClaimedEpoch(address staker, address valAddr) external view returns (uint96) {
    return _getStorageV1().lastClaimedEpoch[staker][valAddr];
  }

  function claimableRewards(address staker) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    address[] memory validators = $.validatorManager.validators();
    uint256 totalClaimable;
    for (uint256 i = 0; i < validators.length; i++) {
      totalClaimable += _claimableRewards($, validators[i], staker);
    }
    return totalClaimable;
  }

  function claimableRewards(address valAddr, address staker) external view returns (uint256) {
    return _claimableRewards(_getStorageV1(), valAddr, staker);
  }

  function claimRewards() external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    address[] memory validators = $.validatorManager.validators();
    uint256 totalClaimable;
    for (uint256 i = 0; i < validators.length; i++) {
      totalClaimable += _claimRewards($, validators[i], MAX_CLAIM_EPOCHS);
    }
    require(totalClaimable > 0, StdError.Unauthorized()); // FIXME(eddy): custom error

    IGovMITO(payable(govMITO)).safeTransfer(_msgSender(), totalClaimable);
    return totalClaimable;
  }

  function claimRewards(address valAddr) external returns (uint256) {
    uint256 totalClaimable = _claimRewards(_getStorageV1(), valAddr, MAX_CLAIM_EPOCHS);
    require(totalClaimable > 0, StdError.Unauthorized()); // FIXME(eddy): custom error

    IGovMITO(payable(govMITO)).safeTransfer(_msgSender(), totalClaimable);
    return totalClaimable;
  }

  function reportRewards(address valAddr, uint256 amount) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    uint96 epoch = $.epochFeeder.epoch();
    $.rewards[epoch][valAddr] += amount;

    IGovMITO(payable(govMITO)).safeTransferFrom(_msgSender(), address(this), amount);
  }

  function reportRewards(address[] calldata valAddrs, uint256[] calldata amounts) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    uint96 epoch = $.epochFeeder.epoch();
    uint256 totalAmount;
    for (uint256 i = 0; i < valAddrs.length; i++) {
      $.rewards[epoch][valAddrs[i]] += amounts[i];
      totalAmount += amounts[i];
    }

    IGovMITO(payable(govMITO)).safeTransferFrom(_msgSender(), address(this), totalAmount);
  }

  function setEpochFeeder(address epochFeeder_) external onlyOwner {
    _setEpochFeeder(epochFeeder_);
  }

  function setValidatorManager(address validatorManager_) external onlyOwner {
    _setValidatorManager(validatorManager_);
  }

  function _setEpochFeeder(address epochFeeder_) internal {
    require(epochFeeder_.code.length > 0, StdError.InvalidAddress('epochFeeder'));
    _getStorageV1().epochFeeder = IEpochFeeder(epochFeeder_);
  }

  function _setValidatorManager(address validatorManager_) internal {
    require(validatorManager_.code.length > 0, StdError.InvalidAddress('validatorManager'));
    _getStorageV1().validatorManager = IValidatorManager(validatorManager_);
  }

  function _claimableRewards(StorageV1 storage $, address valAddr, address staker) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    uint256 totalClaimable;
    (uint96 start, uint96 end) = _claimRange($, staker, valAddr, $.epochFeeder.epoch(), MAX_CLAIM_EPOCHS);
    if (start == end) return 0;

    for (uint96 epoch = start; epoch < end; epoch++) {
      totalClaimable += _claimRewardForEpoch($, valAddr, staker, epoch);
    }

    return totalClaimable;
  }

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

  function _claimRewards(StorageV1 storage $, address valAddr, uint256 epochCount) internal returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    uint256 totalClaimable;
    (uint96 start, uint96 end) = _claimRange($, _msgSender(), valAddr, $.epochFeeder.epoch(), epochCount);
    if (start == end) return 0;

    for (uint96 epoch = start; epoch < end; epoch++) {
      totalClaimable += _claimRewardForEpoch($, valAddr, _msgSender(), epoch);
    }

    $.lastClaimedEpoch[_msgSender()][valAddr] = end;
    return totalClaimable;
  }

  /// @dev stakerRewardPerEpoch = TWAB(delegation[epoch] / totalSupply[epoch]) * rewards
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

    uint256 claimable = (stakerDelegation * rewards_) / totalDelegation;

    return claimable;
  }

  // ====================== UUPS ======================

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
