// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { IEpochFeeder } from '../../interfaces/hub/validator/IEpochFeeder.sol';
import { StdError } from '../../lib/StdError.sol';

/**
 * @title EpochFeeder
 * @notice Manages epoch transitions and timing for the protocol
 * @dev This contract is upgradeable using UUPS pattern
 */
contract EpochFeeder is IEpochFeeder, Ownable2StepUpgradeable, UUPSUpgradeable {
  using SafeCast for uint256;

  /// @dev Current epoch number
  uint256 private _epoch;

  /// @dev Array of epoch timestamps
  uint256[] private _epochs;

  /// @dev Time interval between epochs after the last scheduled epoch
  uint256 private _interval;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, uint256 nextEpochTime_, uint256 interval_) external initializer {
    require(0 < interval_ && interval_ < type(uint48).max, InvalidInterval());
    require(nextEpochTime_ > block.timestamp, StdError.InvalidParameter('nextEpochTime'));

    __UUPSUpgradeable_init();
    __Ownable_init(owner_);
    __Ownable2Step_init();

    _epoch = 0;
    _epochs.push(block.timestamp); // first epoch
    _epochs.push(nextEpochTime_); // next epoch
    _interval = interval_;
  }

  /// @inheritdoc IEpochFeeder
  function clock() public view returns (uint48) {
    return block.timestamp.toUint48();
  }

  /// @inheritdoc IEpochFeeder
  function epoch() public view returns (uint96) {
    uint256 now_ = block.timestamp;
    uint256 epoch_ = _epoch;

    for (uint256 nextEpochTime = _epochs[epoch_ + 1]; nextEpochTime <= now_; epoch_++) {
      uint256 nextEpoch = epoch_ + 1;
      if (nextEpoch >= _epochs.length) nextEpochTime += _interval;
      else nextEpochTime = _epochs[nextEpoch];
    }
    return epoch_.toUint96();
  }

  /// @inheritdoc IEpochFeeder
  function epochAt(uint48 timestamp_) public view returns (uint96) {
    require(timestamp_ != 0, InvalidTimestamp());

    {
      uint256 lastEpoch = _epochs.length - 1;
      uint256 lastEpochTime = _epochs[lastEpoch];
      if (timestamp_ == lastEpochTime) return lastEpoch.toUint96();
      if (timestamp_ > lastEpochTime) return ((timestamp_ - lastEpochTime) / _interval + lastEpoch).toUint96();
    }

    uint256 left = 0;
    uint256 right = _epochs.length - 1;

    while (left < right) {
      uint256 mid = left + (right - left) / 2;
      uint256 midTime = _epochs[mid];

      if (midTime <= timestamp_) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }

    if (_epochs[left] <= timestamp_) {
      return left.toUint96();
    }
    return (left - 1).toUint96();
  }

  /// @inheritdoc IEpochFeeder
  function epochToTime(uint96 epoch_) public view returns (uint48) {
    require(epoch_ >= 0, InvalidEpoch());

    uint256 lastEpoch = _epochs.length - 1;
    if (lastEpoch < epoch_) {
      return ((epoch_ - lastEpoch) * _interval + _epochs[lastEpoch]).toUint48();
    } else {
      return _epochs[epoch_].toUint48();
    }
  }

  /// @inheritdoc IEpochFeeder
  function interval() public view returns (uint48) {
    return _interval.toUint48();
  }

  /// @inheritdoc IEpochFeeder
  function update() external {
    _update();
  }

  function setInterval(uint256 interval_) external onlyOwner {
    require(0 < interval_ && interval_ < type(uint48).max, InvalidInterval());

    _update();

    _epochs.push(_epochs[_epochs.length - 1] + interval_);
    _interval = interval_;

    emit IntervalUpdated(interval_.toUint48());
  }

  /// @dev Updates the current epoch based on the current time
  /// @notice This function will emit EpochRolled events for each epoch transition
  function _update() internal {
    uint256 now_ = clock();
    uint256 epoch_ = _epoch;
    uint256 nextEpochTime = _epochs[epoch_ + 1];

    while (nextEpochTime <= now_) {
      uint256 nextEpoch = epoch_ + 1;

      if (nextEpoch >= _epochs.length) {
        nextEpochTime += _interval;
        _epochs.push(nextEpochTime);
      } else {
        nextEpochTime = _epochs[nextEpoch];
      }

      emit EpochRolled(epoch_.toUint96(), _epochs[epoch_].toUint48());
      epoch_++;
    }

    _epoch = epoch_;
  }

  // ================== UUPS ================== //

  /**
   * @notice Authorizes an upgrade to a new implementation
   * @param newImplementation Address of new implementation
   */
  function _authorizeUpgrade(address newImplementation) internal view override onlyOwner { }
}
