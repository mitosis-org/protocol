// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from './IRewardConfigurator.sol';

/**
 * @title DistributionType
 * @author Manythings Pte. Ltd.
 * @dev Enum representing different types of reward distributions.
 */
enum DistributionType {
  Unspecified,
  MerkleProof,
  TWAB
}

/**
 * @title IRewardDistributorStorage
 * @author Manythings Pte. Ltd.
 * @dev Interface for the storage of reward distributors.
 */
interface IRewardDistributorStorage {
  /**
   * @notice Emitted when a new reward manager is set.
   * @param rewardManager The address of the new reward manager.
   */
  event RewardManagerSet(address indexed rewardManager);

  /**
   * @notice Emitted when a new reward configurator is set.
   * @param rewardConfigurator The address of the new reward configurator.
   */
  event RewardConfiguratorSet(address indexed rewardConfigurator);

  /**
   * @notice Returns the distribution type of the reward distributor.
   * @return The distribution type.
   */
  function distributionType() external view returns (DistributionType);

  /**
   * @notice Returns the description of the reward distributor.
   * @return A string describing the reward distributor.
   */
  function description() external view returns (string memory);

  /**
   * @notice Returns the address of the current reward manager.
   * @return The address of the reward manager.
   */
  function rewardManager() external view returns (address);

  /**
   * @notice Returns the address of the current reward configurator.
   * @return The address of the reward configurator.
   */
  function rewardConfigurator() external view returns (address);
}

/**
 * @title IRewardDistributor
 * @author Manythings Pte. Ltd.
 * @dev Interface for reward distributors, extending IRewardDistributorStorage.
 */
interface IRewardDistributor is IRewardDistributorStorage {
  /**
   * @notice Emitted when a reward is claimed.
   * @param account The address of the account claiming the reward.
   * @param receiver The address receiving the reward.
   * @param eligibleRewardAsset The address of the eligible reward asset.
   * @param reward The address of the reward token.
   * @param amount The amount of reward claimed.
   */
  event Claimed(
    address indexed account,
    address indexed receiver,
    address indexed eligibleRewardAsset,
    address reward,
    uint256 amount
  );

  /**
   * @notice Emitted when a reward is handled.
   * @param eligibleRewardAsset The address of the eligible reward asset.
   * @param reward The address of the reward token.
   * @param amount The amount of reward handled.
   * @param batchTimestamp The timestamp of the batch.
   * @param distributionType The type of distribution used.
   * @param metadata Additional metadata about the reward handling.
   */
  event RewardHandled(
    address indexed eligibleRewardAsset,
    address indexed reward,
    uint256 indexed amount,
    uint256 batchTimestamp,
    DistributionType distributionType,
    bytes metadata
  );

  /**
   * @notice Checks if an account can claim a reward.
   * @param account The address of the account to check.
   * @param reward The address of the reward token.
   * @param metadata Additional metadata for the claim check.
   * @return A boolean indicating whether the account can claim the reward.
   */
  function claimable(address account, address reward, bytes calldata metadata) external view returns (bool);

  /**
   * @notice Returns the claimable amount for an account.
   * @param account The address of the account to check.
   * @param reward The address of the reward token.
   * @param metadata Additional metadata for the claim amount check.
   * @return The amount of reward claimable by the account.
   */
  function claimableAmount(address account, address reward, bytes calldata metadata) external view returns (uint256);

  /**
   * @notice Claims a reward for the caller.
   * @param reward The address of the reward token.
   * @param metadata Additional metadata for the claim.
   */
  function claim(address reward, bytes calldata metadata) external;

  /**
   * @notice Claims a reward for a specified receiver.
   * @param receiver The address to receive the reward.
   * @param reward The address of the reward token.
   * @param metadata Additional metadata for the claim.
   */
  function claim(address receiver, address reward, bytes calldata metadata) external;

  /**
   * @notice Claims a specific amount of reward for the caller.
   * @param reward The address of the reward token.
   * @param amount The amount of reward to claim.
   * @param metadata Additional metadata for the claim.
   */
  function claim(address reward, uint256 amount, bytes calldata metadata) external;

  /**
   * @notice Claims a specific amount of reward for a specified receiver.
   * @param receiver The address to receive the reward.
   * @param reward The address of the reward token.
   * @param amount The amount of reward to claim.
   * @param metadata Additional metadata for the claim.
   */
  function claim(address receiver, address reward, uint256 amount, bytes calldata metadata) external;

  /**
   * @notice Handles a reward distribution.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param amount The amount of reward to handle.
   * @param metadata Additional metadata for the reward handling.
   */
  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external;

  /**
   * @notice Sets a new reward manager.
   * @param rewardManager_ The address of the new reward manager.
   */
  function setRewardManager(address rewardManager_) external;

  /**
   * @notice Sets a new reward configurator.
   * @param rewardConfigurator_ The address of the new reward configurator.
   */
  function setRewardConfigurator(address rewardConfigurator_) external;
}
