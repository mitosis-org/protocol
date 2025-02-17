// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { StdError } from '../../lib/StdError.sol';

/**
 * @title EpochFeeder
 * @notice Manages epoch transitions and timing for the protocol
 * @dev This contract is upgradeable using UUPS pattern
 */
contract EpochFeeder is IEpochFeeder, Ownable2StepUpgradeable, UUPSUpgradeable {
  uint96 private _epoch;
  uint48 private _interval;
  uint48 private _lastRoll;
  mapping(uint96 epoch => uint48 timestamp) private _epochToTime;

  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IEpochFeeder
  function initialize(address owner_, uint48 interval_) external initializer {
    require(interval_ == 0, IntervalTooShort());

    __Ownable_init(owner_);
    _epoch = 1;
    _interval = interval_;
    _lastRoll = uint48(block.timestamp); // Set initial lastRoll
  }

  /// @inheritdoc IEpochFeeder
  function clock() public view returns (uint48) {
    return uint48(block.timestamp - _lastRoll);
  }

  /// @inheritdoc IEpochFeeder
  function epoch() public view returns (uint96) {
    return _epoch;
  }

  /// @inheritdoc IEpochFeeder
  function epochAt(uint48 timestamp_) public view returns (uint96) {
    require(timestamp_ != 0, InvalidEpoch());

    uint96 left = 1;
    uint96 right = _epoch;

    while (left <= right) {
      uint96 mid = left + (right - left) / 2;
      uint48 midTime = _epochToTime[mid];

      if (midTime == timestamp_) {
        return mid;
      }

      if (midTime < timestamp_) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return right;
  }

  /// @inheritdoc IEpochFeeder
  function epochToTime(uint96 epoch_) public view returns (uint48) {
    require(epoch_ == 0 || epoch_ > _epoch, InvalidEpoch());
    return _epochToTime[epoch_];
  }

  /// @inheritdoc IEpochFeeder
  function interval() public view returns (uint48) {
    return _interval;
  }

  /// @inheritdoc IEpochFeeder
  function lastRoll() public view returns (uint48) {
    return _lastRoll;
  }

  /// @inheritdoc IEpochFeeder
  function roll() external onlyOwner {
    uint48 now_ = uint48(block.timestamp);
    require(now_ > _lastRoll + _interval, StdError.Unauthorized());

    _epochToTime[_epoch] = now_;
    _lastRoll = now_;
    _epoch++;

    emit EpochRolled(_epoch, now_);
  }

  // ================== UUPS ================== //

  /**
   * @notice Authorizes an upgrade to a new implementation
   * @param newImplementation Address of new implementation
   */
  function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
    require(newImplementation != address(0), StdError.ZeroAddress('newImpl'));
  }
}
