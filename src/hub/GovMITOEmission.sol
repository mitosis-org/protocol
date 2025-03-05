// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../interfaces/hub/IGovMITOEmission.sol';
import { IEpochFeeder } from '../interfaces/hub/validator/IEpochFeeder.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract GovMITOEmissionStorageV1 {
  using ERC7201Utils for string;

  struct ValidatorRewardEmission {
    uint256 rps;
    uint160 deductionRate; // 10000 = 100%
    uint48 deductionPeriod;
    uint48 timestamp;
  }

  struct ValidatorReward {
    ValidatorRewardEmission[] emissions;
    uint256 total;
    uint256 spent;
    address recipient;
  }

  struct StorageV1 {
    ValidatorReward validatorReward;
  }

  string private constant _NAMESPACE = 'mitosis.storage.GovMITOEmission';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

/// @title GovMITOEmission
/// @notice This contract is used to manage the emission of GovMITO
/// @dev This is very temporary contract. We need to think more about the design of the emission management.
contract GovMITOEmission is IGovMITOEmission, GovMITOEmissionStorageV1, UUPSUpgradeable, Ownable2StepUpgradeable {
  using SafeERC20 for IGovMITO;
  using SafeCast for uint256;

  uint256 public constant DEDUCTION_RATE_DENOMINATOR = 10000;

  IGovMITO private immutable _govMITO;
  IEpochFeeder private immutable _epochFeeder;

  constructor(IGovMITO govMITO_, IEpochFeeder epochFeeder_) {
    _disableInitializers();

    _govMITO = govMITO_;
    _epochFeeder = epochFeeder_;
  }

  function initialize(address initialOwner, ValidatorRewardConfig memory config) external payable initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner);
    __Ownable2Step_init();

    uint48 currentTime = Time.timestamp();
    require(config.total == msg.value, StdError.InvalidParameter('config.total'));
    require(config.startsFrom > currentTime, StdError.InvalidParameter('config.ssf'));
    require(config.recipient != address(0), StdError.InvalidParameter('config.rcp'));

    StorageV1 storage $ = _getStorageV1();

    _configureValidatorRewardEmission($, config.rps, config.deductionRate, config.deductionPeriod, config.startsFrom);

    $.validatorReward.total = config.total;
    $.validatorReward.spent = 0;
    $.validatorReward.recipient = config.recipient;

    // convert the total amount to gMITO
    _govMITO.mint{ value: config.total }(address(this));
  }

  /// @inheritdoc IGovMITOEmission
  function govMITO() external view returns (IGovMITO) {
    return _govMITO;
  }

  /// @inheritdoc IGovMITOEmission
  function epochFeeder() external view returns (IEpochFeeder) {
    return _epochFeeder;
  }

  /// @inheritdoc IGovMITOEmission
  function validatorReward(uint256 epoch) external view returns (uint256) {
    return _calcValidatorRewardForEpoch(_getStorageV1(), epoch);
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardTotal() external view returns (uint256) {
    return _getStorageV1().validatorReward.total;
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardSpent() external view returns (uint256) {
    return _getStorageV1().validatorReward.spent;
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardEmissionsCount() external view returns (uint256) {
    return _getStorageV1().validatorReward.emissions.length;
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardEmissionsByIndex(uint256 index) external view returns (uint256, uint160, uint48) {
    ValidatorRewardEmission memory emission = _getStorageV1().validatorReward.emissions[index];
    return (emission.rps, emission.deductionRate, emission.deductionPeriod);
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardEmissionsByTime(uint48 timestamp) external view returns (uint256, uint160, uint48) {
    ValidatorRewardEmission memory emission = _lowerLookup(_getStorageV1().validatorReward.emissions, timestamp);

    uint256 rps = emission.rps;
    uint160 deductionRate = emission.deductionRate;
    uint48 deductionPeriod = emission.deductionPeriod;

    uint48 lastDeducted = emission.timestamp;
    uint48 endTime = Time.timestamp();

    while (lastDeducted < endTime) {
      uint48 nextDeduction = lastDeducted + deductionPeriod;
      rps = Math.mulDiv(rps, DEDUCTION_RATE_DENOMINATOR - deductionRate, DEDUCTION_RATE_DENOMINATOR);
      lastDeducted = nextDeduction;
    }

    return (rps, deductionRate, deductionPeriod);
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardRecipient() external view returns (address) {
    return _getStorageV1().validatorReward.recipient;
  }

  /// @inheritdoc IGovMITOEmission
  function requestValidatorReward(uint256 epoch, address recipient, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    require($.validatorReward.recipient == _msgSender(), StdError.Unauthorized());

    uint256 spent = $.validatorReward.spent;
    require($.validatorReward.total >= spent + amount, NotEnoughReserve());

    $.validatorReward.spent += amount;
    _govMITO.safeTransfer(recipient, amount);

    emit ValidatorRewardRequested(epoch, amount);
  }

  /// @inheritdoc IGovMITOEmission
  function addValidatorRewardEmission() external payable onlyOwner {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    StorageV1 storage $ = _getStorageV1();

    $.validatorReward.total += msg.value;
    _govMITO.mint{ value: msg.value }(address(this));

    emit ValidatorRewardEmissionAdded(msg.value);
  }

  /// @inheritdoc IGovMITOEmission
  function configureValidatorRewardEmission(uint256 rps, uint160 deductionRate, uint48 deductionPeriod)
    external
    onlyOwner
  {
    _configureValidatorRewardEmission(_getStorageV1(), rps, deductionRate, deductionPeriod, Time.timestamp());
  }

  function _configureValidatorRewardEmission(
    StorageV1 storage $,
    uint256 rps,
    uint160 deductionRate,
    uint48 deductionPeriod,
    uint48 timestamp
  ) internal {
    uint48 now_ = Time.timestamp();

    require(rps > 0, StdError.InvalidParameter('rps'));
    require(deductionRate <= DEDUCTION_RATE_DENOMINATOR, StdError.InvalidParameter('deductionRate'));
    require(deductionPeriod > 0, StdError.InvalidParameter('deductionPeriod'));
    require(now_ <= timestamp, StdError.InvalidParameter('timestamp'));

    $.validatorReward.emissions.push(
      ValidatorRewardEmission({
        rps: rps,
        deductionRate: deductionRate,
        deductionPeriod: deductionPeriod,
        timestamp: timestamp
      })
    );

    emit ValidatorRewardEmissionConfigured(rps, deductionRate, deductionPeriod, timestamp);
  }

  function _calcRewardForPeriod(
    uint256 rps,
    uint256 deductionRate,
    uint48 deductionPeriod,
    uint48 lastDeducted,
    uint48 lastUpdated,
    uint48 endTime
  ) internal pure returns (uint256 reward) {
    while (lastDeducted < endTime) {
      uint48 nextDeduction = lastDeducted + deductionPeriod;
      if (lastUpdated < nextDeduction) {
        uint48 rewardEndTime = Math.min(endTime, nextDeduction).toUint48();
        reward += rps * (rewardEndTime - lastUpdated);
        lastUpdated = rewardEndTime;
      }
      rps = Math.mulDiv(rps, DEDUCTION_RATE_DENOMINATOR - deductionRate, DEDUCTION_RATE_DENOMINATOR);
      lastDeducted = nextDeduction;
    }
  }

  function _calcValidatorRewardForEpoch(StorageV1 storage $, uint256 epoch) internal view returns (uint256) {
    require(0 <= epoch, StdError.InvalidParameter('epoch'));

    uint48 epochStartTime = _epochFeeder.timeAt(epoch);
    uint48 epochEndTime = _epochFeeder.timeAt(epoch + 1) - 1;

    ValidatorReward storage vr = $.validatorReward;
    ValidatorRewardEmission memory startLog = _lowerLookup(vr.emissions, epochStartTime);
    ValidatorRewardEmission memory endLog = _lowerLookup(vr.emissions, epochEndTime);
    if (endLog.timestamp == 0) return 0;

    // Determine which log to use based on timestamps
    ValidatorRewardEmission memory activeLog = startLog.timestamp == 0 ? endLog : startLog;
    uint48 startTime = startLog.timestamp == 0 ? endLog.timestamp : epochStartTime;

    // Calculate initial reward period
    uint256 reward = _calcRewardForPeriod(
      activeLog.rps,
      activeLog.deductionRate,
      activeLog.deductionPeriod,
      activeLog.timestamp,
      startTime,
      startLog.timestamp == endLog.timestamp ? epochEndTime : endLog.timestamp - 1
    );

    // Add second period if logs are different
    if (startLog.timestamp != endLog.timestamp && startLog.timestamp != 0) {
      reward += _calcRewardForPeriod(
        endLog.rps, //
        endLog.deductionRate,
        endLog.deductionPeriod,
        endLog.timestamp,
        endLog.timestamp,
        epochEndTime
      );
    }

    return reward;
  }

  function _latest(ValidatorRewardEmission[] storage self) internal view returns (ValidatorRewardEmission memory) {
    return self[self.length - 1];
  }

  function _lowerLookup(ValidatorRewardEmission[] storage self, uint48 timestamp)
    internal
    view
    returns (ValidatorRewardEmission memory)
  {
    uint256 len = self.length;
    uint256 pos = _lowerBinaryLookup(self, timestamp, 0, len);
    if (pos == len) {
      ValidatorRewardEmission memory empty;
      return empty;
    }
    return self[pos];
  }

  function _lowerBinaryLookup(ValidatorRewardEmission[] storage self, uint48 key, uint256 low, uint256 high)
    private
    view
    returns (uint256)
  {
    while (low < high) {
      uint256 mid = Math.average(low, high);
      if (self[mid].timestamp < key) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return high;
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address) internal view override onlyOwner { }
}
