// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IValidatorRewardDistributor
/// @notice Interface for the ValidatorRewardDistributor contract that handles distribution of validator rewards
interface IValidatorRewardDistributor {
  /// @notice Returns the epoch feeder contract
  function epochFeeder() external view returns (address);

  /// @notice Returns the validator manager contract
  function validatorManager() external view returns (address);

  /// @notice Returns the rewards for a validator in a given epoch
  function rewards(uint96 epoch, address valAddr) external view returns (uint256);

  /// @notice Returns the last claimed epoch for a staker and validator
  function lastClaimedEpoch(address staker, address valAddr) external view returns (uint96);

  /// @notice Claims rewards for a validator over a range of epochs
  /// @param valAddr The validator address to claim rewards for
  /// @param staker The staker address to claim rewards for
  /// @return The total amount of rewards that can be claimed
  function claimableRewards(address valAddr, address staker) external view returns (uint256);

  /// @notice Claims rewards for a validator over a range of epochs
  /// @param valAddr The validator address to claim rewards for
  /// @param epochCount The number of epochs to claim rewards for (max 32)
  /// @return The total amount of rewards that were claimed
  function claimRewards(address valAddr, uint256 epochCount) external returns (uint256);

  /// @notice Reports rewards for a single validator for the current epoch
  /// @param valAddr The validator address to report rewards for
  /// @param amount The amount of rewards to report
  function reportRewards(address valAddr, uint256 amount) external;

  /// @notice Reports rewards for multiple validators for the current epoch
  /// @param valAddrs Array of validator addresses to report rewards for
  /// @param amounts Array of reward amounts corresponding to each validator
  function reportRewards(address[] calldata valAddrs, uint256[] calldata amounts) external;
}
