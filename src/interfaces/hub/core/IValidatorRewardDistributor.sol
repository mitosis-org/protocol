// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IEpochFeeder } from './IEpochFeeder.sol';
import { IValidatorManager } from './IValidatorManager.sol';

/// @title IValidatorRewardDistributor
/// @notice Interface for the ValidatorRewardDistributor contract that handles distribution of validator rewards
interface IValidatorRewardDistributor {
  /// @notice Returns the epoch feeder contract
  function epochFeeder() external view returns (IEpochFeeder);

  /// @notice Returns the validator manager contract
  function validatorManager() external view returns (IValidatorManager);

  /// @notice Returns the rewards for a validator in a given epoch
  function rewards(uint96 epoch, address valAddr) external view returns (uint256);

  /// @notice Returns the last claimed epoch for a staker and validator
  function lastClaimedEpoch(address staker, address valAddr) external view returns (uint96);

  /// @notice Returns the total claimable rewards for a validator and staker
  /// @param valAddr The validator address to claim rewards for
  /// @param staker The staker address to claim rewards for
  /// @return amount The total amount of rewards that can be claimed
  function claimableRewards(address valAddr, address staker) external view returns (uint256);

  /// @notice Returns the total claimable rewards for multiple validators and a staker
  /// @param valAddrs Array of validator addresses to check rewards for
  /// @param staker The staker address to check rewards for
  /// @return amount The total amount of rewards that can be claimed
  function claimableRewards(address[] memory valAddrs, address staker) external view returns (uint256);

  /// @notice Claims rewards for a validator over a range of epochs
  /// @param valAddr The validator address to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function claimRewards(address valAddr) external returns (uint256);

  /// @notice Claims rewards for multiple validators over a range of epochs
  /// @param valAddrs Array of validator addresses to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function claimRewards(address[] calldata valAddrs) external returns (uint256);

  /// @notice Reports rewards for a single validator for the current epoch
  /// @param valAddr The validator address to report rewards for
  /// @param amount The amount of rewards to report
  function reportRewards(address valAddr, uint256 amount) external;

  /// @notice Reports rewards for multiple validators for the current epoch
  /// @param valAddrs Array of validator addresses to report rewards for
  /// @param amounts Array of reward amounts corresponding to each validator
  function reportRewards(address[] calldata valAddrs, uint256[] calldata amounts) external;
}
