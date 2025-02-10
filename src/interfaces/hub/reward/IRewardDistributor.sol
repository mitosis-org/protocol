// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRewardDistributor
 * @notice Common interface for distributor of rewards.
 */
interface IRewardDistributor {
  event RewardHandled(address indexed eolVault, address indexed reward, uint256 indexed amount);

  /**
   * @notice Handles the distribution of rewards for the specified vault and reward.
   */
  function handleReward(address eolVault, address reward, uint256 amount) external;
}
