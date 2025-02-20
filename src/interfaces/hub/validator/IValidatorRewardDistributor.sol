// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IGovMITO } from '../IGovMITO.sol';
import { IGovMITOEmission } from '../IGovMITOEmission.sol';
import { IEpochFeeder } from './IEpochFeeder.sol';
import { IValidatorContributionFeed } from './IValidatorContributionFeed.sol';
import { IValidatorManager } from './IValidatorManager.sol';
import { IValidatorStaking } from './IValidatorStaking.sol';

/// @title IValidatorRewardDistributor
/// @notice Interface for the ValidatorRewardDistributor contract that handles distribution of validator rewards
interface IValidatorRewardDistributor {
  // Events
  event RewardsReported(address indexed valAddr, uint256 amount, uint96 epoch);
  event RewardsClaimed(
    address indexed staker, address indexed valAddr, uint256 amount, uint96 fromEpoch, uint96 toEpoch
  );
  event EpochFeederSet(address indexed epochFeeder);
  event ValidatorManagerSet(address indexed validatorManager);

  // Custom errors
  error NotValidator();
  error ArrayLengthMismatch();

  // ========== VIEWS ========== //

  /// @notice Returns the gov MITO contract
  function govMITO() external view returns (IGovMITO);

  /// @notice Returns the epoch feeder contract
  function epochFeeder() external view returns (IEpochFeeder);

  /// @notice Returns the validator registry contract
  function validatorManager() external view returns (IValidatorManager);

  /// @notice Returns the validator contribution feed contract
  function validatorContributionFeed() external view returns (IValidatorContributionFeed);

  /// @notice Returns the validator delegation manager contract
  function validatorStaking() external view returns (IValidatorStaking);

  /// @notice Returns the gov MITO emission contract
  function govMITOEmission() external view returns (IGovMITOEmission);

  /// @notice Returns the last claimed staker rewards epoch for a validator
  /// @param staker The staker address to check rewards for
  /// @param valAddr The validator address to check rewards for
  /// @return epoch The last claimed staker rewards epoch
  function lastClaimedStakerRewardsEpoch(address staker, address valAddr) external view returns (uint96);

  /// @notice Returns the last claimed operator rewards epoch for a validator
  /// @param valAddr The validator address to check rewards for
  /// @return epoch The last claimed operator rewards epoch
  function lastClaimedOperatorRewardsEpoch(address valAddr) external view returns (uint96);

  /// @notice Returns the total claimable rewards for multiple validators and a staker
  /// @param staker The staker address to check rewards for
  /// @param valAddr The validator address to check rewards for
  /// @return amount The total amount of rewards that can be claimed
  /// @return nextEpoch The next epoch to claim rewards from
  function claimableStakerRewards(address staker, address valAddr) external view returns (uint256, uint96);

  /// @notice Returns the total claimable operator rewards for a validator
  /// @param valAddr The validator address to check rewards for
  /// @return amount The total amount of rewards that can be claimed
  /// @return nextEpoch The next epoch to claim rewards from
  function claimableOperatorRewards(address valAddr) external view returns (uint256, uint96);

  /// @notice Claims rewards for multiple validators over a range of epochs
  /// @param staker The staker address to claim rewards for
  /// @param valAddr The validator address to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function claimStakerRewards(address staker, address valAddr) external returns (uint256);

  /// @notice Claims rewards for multiple validators over a range of epochs
  /// @param stakers The staker addresses to claim rewards for
  /// @param valAddrs The validator addresses to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function batchClaimStakerRewards(address[] calldata stakers, address[][] calldata valAddrs)
    external
    returns (uint256);

  /// @notice Claims operator rewards for a validator
  /// @param valAddr The validator address to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function claimOperatorRewards(address valAddr) external returns (uint256);

  /// @notice Claims operator rewards for multiple validators
  /// @param valAddrs The validator addresses to claim rewards for
  /// @return amount The total amount of rewards that were claimed
  function batchClaimOperatorRewards(address[] calldata valAddrs) external returns (uint256);
}
