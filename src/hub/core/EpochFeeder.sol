// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { StdError } from '../../lib/StdError.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

interface IEpochFeeder {
  function clock() external view returns (uint48);
  function epoch() external view returns (uint96);
  function epochToTime(uint96 epoch) external view returns (uint48);
  function interval() external view returns (uint48);
  function lastRoll() external view returns (uint48);
  function roll() external;
}

contract EpochFeeder is IEpochFeeder, Ownable2StepUpgradeable {
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

    _lastRoll = now_;
    _epoch++;
  }
}
