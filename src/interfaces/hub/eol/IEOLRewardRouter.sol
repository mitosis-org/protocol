// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, DistributionType } from '../reward/IRewardDistributor.sol';

/**
 * @title IEOLRewardRouter
 * @dev Interface for routing and managing EOL rewards.
 */
interface IEOLRewardRouter {
  /**
   * @notice Emitted when a reward manager is set.
   * @param account The address of the new reward manager.
   */
  event RewardManagerSet(address indexed account);

  /**
   * @notice Emitted when a reward is dispatched to a distributor.
   * @param rewardDistributor The address of the reward distributor.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param amount The amount of reward tokens dispatched.
   */
  event Dispatched(address indexed rewardDistributor, address indexed eolVault, address indexed reward, uint256 amount);

  /**
   * @notice Emitted when the EOL share value is increased.
   * @param eolVault The address of the EOL vault.
   * @param amount The amount by which the share value increased.
   */
  event EOLShareValueIncreased(address indexed eolVault, uint256 indexed amount);

  /**
   * @notice Emitted when a claimable reward is routed.
   * @param rewardDistributor The address of the reward distributor.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param distributionType The type of distribution used.
   * @param amount The amount of reward tokens routed.
   */
  event RouteClaimableReward(
    address indexed rewardDistributor,
    address indexed eolVault,
    address indexed reward,
    DistributionType distributionType,
    uint256 amount
  );

  /**
   * @notice Emitted when an unspecified reward is received.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param timestamp The timestamp when the reward was received.
   * @param index The index of the reward in the treasury.
   * @param amount The amount of reward tokens received.
   */
  event UnspecifiedReward(
    address indexed eolVault, address indexed reward, uint48 timestamp, uint256 index, uint256 amount
  );

  /**
   * @notice Error thrown when an invalid dispatch request is made.
   * @param reward The address of the reward token.
   * @param index The index of the invalid request.
   */
  error IEOLRewardManager__InvalidDispatchRequest(address reward, uint256 index);

  /**
   * @notice Checks if an account is a reward manager.
   * @param account The address to check.
   * @return A boolean indicating whether the account is a reward manager.
   */
  function isRewardManager(address account) external view returns (bool);

  /**
   * @notice Retrieves reward information from the treasury for a specific EOL vault and reward token.
   * @param eolVault The address of the EOL vault.
   * @param reward_ The address of the reward token.
   * @param timestamp The timestamp to retrieve information for.
   * @return amounts An array of reward amounts.
   * @return dispatched An array of booleans indicating whether each reward has been dispatched.
   */
  function getRewardTreasuryRewardInfos(address eolVault, address reward_, uint48 timestamp)
    external
    view
    returns (uint256[] memory amounts, bool[] memory dispatched);

  /**
   * @notice Sets a new reward manager.
   * @param account The address of the new reward manager.
   */
  function setRewardManager(address account) external;

  /**
   * @notice Routes extra rewards to the appropriate distributor.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param amount The amount of reward tokens to route.
   */
  function routeExtraRewards(address eolVault, address reward, uint256 amount) external;

  /**
   * @notice Dispatches rewards to a specific distributor for multiple indexes.
   * @param distributor The address of the reward distributor.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param timestamp The timestamp of the rewards.
   * @param indexes An array of indexes to dispatch.
   * @param metadata An array of metadata for each dispatch.
   */
  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external;

  /**
   * @notice Dispatches a reward to a specific distributor for a single index.
   * @param distributor The address of the reward distributor.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param timestamp The timestamp of the reward.
   * @param index The index of the reward to dispatch.
   * @param metadata The metadata for the dispatch.
   */
  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external;
}
