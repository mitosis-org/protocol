// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRewardDistributor
 * @notice Common interface for distributor of rewards.
 */
interface IRewardDistributor {
  event RewardHandled(
    address indexed eolVault, address indexed reward, uint256 indexed amount, bytes metadata, bytes extraData
  );

  /**
   * @notice Handles the distribution of rewards for the specified vault and reward
   * @dev This method can only be called by the account that is allowed to dispatch rewards
   */
  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external;
}
