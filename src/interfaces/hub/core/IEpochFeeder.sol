// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IEpochFeeder {
  function clock() external view returns (uint48);
  function epoch() external view returns (uint96);
  function epochAt(uint48 timestamp_) external view returns (uint96);
  function epochToTime(uint96 epoch) external view returns (uint48);
  function interval() external view returns (uint48);
  function lastRoll() external view returns (uint48);
  function roll() external;
}
