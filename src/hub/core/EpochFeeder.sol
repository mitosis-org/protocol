// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { StdError } from '../../lib/StdError.sol';

contract EpochFeeder is IEpochFeeder, Ownable2StepUpgradeable, UUPSUpgradeable {
  uint96 private _epoch;
  uint48 private _interval;
  uint48 private _lastRoll;
  mapping(uint96 epoch => uint48 timestamp) private _epochToTime;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, uint48 interval_) external initializer {
    __Ownable_init(owner_);
    _epoch = 1;
    _interval = interval_;
  }

  function clock() public view returns (uint48) {
    return uint48(block.timestamp - _lastRoll);
  }

  function epoch() public view returns (uint96) {
    return _epoch;
  }

  function epochAt(uint48 timestamp_) public view returns (uint96) {
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

  function epochToTime(uint96 epoch_) public view returns (uint48) {
    return _epochToTime[epoch_];
  }

  function interval() public view returns (uint48) {
    return _interval;
  }

  function lastRoll() public view returns (uint48) {
    return _lastRoll;
  }

  function roll() external onlyOwner {
    uint48 now_ = clock();
    require(now_ > _lastRoll + _interval, StdError.Unauthorized());

    _epochToTime[_epoch] = now_;

    _lastRoll = now_;
    _epoch++;
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
