// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IEpochFeeder
/// @notice Interface for managing epoch transitions and timing in the protocol
interface IEpochFeeder {
  /// @notice Emitted when a new epoch is rolled
  /// @param epoch The new epoch number
  /// @param timestamp The timestamp when the epoch was rolled
  event EpochRolled(uint96 indexed epoch, uint48 timestamp);

  /// @dev Thrown when interval is set to zero
  error IntervalTooShort();

  /// @dev Thrown when epoch is invalid (zero or greater than current)
  error InvalidEpoch();

  /// @notice Returns time elapsed since last roll
  /// @return timestamp Current clock time in seconds since last roll
  function clock() external view returns (uint48);

  /// @notice Returns current epoch number, starting from 1
  /// @return epochCurrent epoch number
  function epoch() external view returns (uint96);

  /// @notice Finds epoch number at a given timestamp using binary search
  /// @param timestamp_ Timestamp to query
  /// @return epoch Epoch number at that timestamp
  /// @dev Reverts if timestamp is 0
  function epochAt(uint48 timestamp_) external view returns (uint96);

  /// @notice Gets timestamp for a specific epoch
  /// @param epoch Epoch number to query
  /// @return timestamp Timestamp when that epoch was created
  /// @dev Reverts if epoch is 0 or greater than current epoch
  function epochToTime(uint96 epoch) external view returns (uint48);

  /// @notice Returns interval between epochs
  /// @return interval Current interval in seconds
  function interval() external view returns (uint48);

  /// @notice Returns timestamp of last epoch roll
  /// @return timestamp Timestamp of last roll
  function lastRoll() external view returns (uint48);

  /// @notice Advances to next epoch if interval has passed
  /// @dev Only callable by owner
  /// @dev Reverts if insufficient time has passed since last roll
  function roll() external;
}
