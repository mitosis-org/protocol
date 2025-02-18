// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  IValidatorContributionFeedNotifier,
  ValidatorWeight,
  ReportStatus
} from '../../interfaces/hub/core/IValidatorContributionFeed.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

contract ValidatorContributionFeedStorageV1 {
  using ERC7201Utils for string;

  struct ReportChecker {
    uint128 totalWeight;
    uint16 numOfValidators; // max 65535
  }

  struct Reward {
    ReportStatus status;
    uint128 totalReward;
    uint128 totalWeight;
    ValidatorWeight[] weights;
    mapping(address valAddr => uint256 index) weightByValAddr;
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IValidatorContributionFeedNotifier notifier;
    uint96 nextEpoch;
    ReportChecker checker;
    mapping(uint96 epoch => Reward reward) rewards;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorContributionFeedStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorContributionFeed is
  IValidatorContributionFeed,
  ValidatorContributionFeedStorageV1,
  Ownable2StepUpgradeable,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable
{
  using SafeCast for uint256;
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  /// @notice keccak256('mitosis.role.ValidatorContributionFeed.feeder')
  bytes32 public constant FEEDER_ROLE = 0xed3cedcdadd7625ff13ce12c112792caf5f35e0f515e9d8bd5cb9ad0c4cd4262;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address epochFeeder_) external initializer {
    require(owner_ != address(0), StdError.ZeroAddress('owner'));

    __UUPSUpgradeable_init();
    __Ownable_init(owner_);
    __Ownable2Step_init();
    __AccessControl_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, owner_);

    StorageV1 storage $ = _getStorageV1();

    $.nextEpoch = 1;

    _setEpochFeeder($, epochFeeder_);
  }

  function epochFeeder() external view returns (IEpochFeeder) {
    return _getStorageV1().epochFeeder;
  }

  function weightCount(uint96 epoch) external view returns (uint256) {
    return _getStorageV1().rewards[epoch].weights.length;
  }

  function weightAt(uint96 epoch, uint256 index) external view returns (ValidatorWeight memory) {
    return _getStorageV1().rewards[epoch].weights[index];
  }

  function weightOf(uint96 epoch, address valAddr) external view returns (ValidatorWeight memory, bool) {
    StorageV1 storage $ = _getStorageV1();
    Reward storage reward = $.rewards[epoch];

    require(reward.status == ReportStatus.FINALIZED, StdError.Unauthorized());

    uint256 index = reward.weightByValAddr[valAddr];
    if (index == 0 && (reward.weights.length == 0 || reward.weights[0].addr != valAddr)) {
      ValidatorWeight memory empty;
      return (empty, false);
    }
    return (reward.weights[index], true);
  }

  function summary(uint96 epoch) external view returns (Summary memory) {
    StorageV1 storage $ = _getStorageV1();
    Reward storage reward = $.rewards[epoch];

    require(reward.status == ReportStatus.FINALIZED, StdError.Unauthorized());

    return Summary({
      totalReward: reward.totalReward,
      totalWeight: reward.totalWeight,
      numOfValidators: reward.weights.length.toUint16()
    });
  }

  function initializeReport(InitReportRequest calldata request) external onlyRole(FEEDER_ROLE) {
    StorageV1 storage $ = _getStorageV1();
    require(address($.notifier) != address(0), NotifierNotSet());

    uint96 epoch = $.nextEpoch;

    require(epoch < $.epochFeeder.epoch(), StdError.InvalidParameter('epoch'));

    Reward storage reward = $.rewards[epoch];
    require(reward.status == ReportStatus.NONE, InvalidReportStatus());

    reward.status = ReportStatus.INITIALIZED;
    reward.totalReward = request.totalReward;
    reward.totalWeight = request.totalWeight;

    emit ReportInitialized(epoch, request.totalReward, request.totalWeight, request.numOfValidators);
  }

  function pushValidatorWeights(ValidatorWeight[] calldata weights) external onlyRole(FEEDER_ROLE) {
    StorageV1 storage $ = _getStorageV1();
    uint96 epoch = $.nextEpoch;

    Reward storage reward = $.rewards[epoch];
    require(reward.status == ReportStatus.INITIALIZED, InvalidReportStatus());

    ReportChecker memory checker = $.checker;

    for (uint256 i = 0; i < weights.length; i++) {
      ValidatorWeight memory weight = weights[i];
      uint256 index = reward.weightByValAddr[weight.addr];

      require(
        index == 0 && (reward.weights.length == 0 || reward.weights[index].addr == weight.addr), InvalidWeightAddress()
      );

      reward.weights.push(weight);
      reward.weightByValAddr[weight.addr] = i;
      checker.totalWeight += weight.weight;
    }

    checker.numOfValidators += uint16(weights.length);

    uint128 prevTotalWeight = $.checker.totalWeight;
    $.checker = checker;

    emit WeightsPushed(epoch, checker.totalWeight - prevTotalWeight, weights.length.toUint16());
  }

  function finalizeReport() external onlyRole(FEEDER_ROLE) {
    StorageV1 storage $ = _getStorageV1();
    uint96 epoch = $.nextEpoch;

    Reward storage reward = $.rewards[epoch];
    require(reward.status == ReportStatus.INITIALIZED, InvalidReportStatus());

    ReportChecker memory checker = $.checker;
    require(checker.totalWeight == reward.totalWeight, InvalidTotalWeight());
    require(checker.numOfValidators == reward.weights.length, InvalidValidatorCount());

    reward.status = ReportStatus.FINALIZED;

    $.nextEpoch++;
    delete $.checker;

    $.notifier.notifyReportFinalized(epoch);

    emit ReportFinalized(epoch);
  }

  function setEpochFeeder(IEpochFeeder epochFeeder_) external onlyOwner {
    _setEpochFeeder(_getStorageV1(), address(epochFeeder_));
  }

  function setNotifier(IValidatorContributionFeedNotifier notifier) external onlyOwner {
    _setNotifier(_getStorageV1(), address(notifier));
  }

  function _setEpochFeeder(StorageV1 storage $, address epochFeeder_) internal {
    require(epochFeeder_.code.length > 0, StdError.InvalidParameter('epochFeeder'));
    $.epochFeeder = IEpochFeeder(epochFeeder_);
  }

  function _setNotifier(StorageV1 storage $, address notifier_) internal {
    require(notifier_.code.length > 0, StdError.InvalidParameter('notifier'));
    $.notifier = IValidatorContributionFeedNotifier(notifier_);
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
    require(newImplementation != address(0), StdError.ZeroAddress('newImpl'));
  }
}
