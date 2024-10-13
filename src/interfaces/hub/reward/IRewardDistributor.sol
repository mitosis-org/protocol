// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardHandler } from './IRewardHandler.sol';

/**
 * @title IRewardDistributor
 * @notice Common interface for distributor of rewards.
 */
interface IRewardDistributor is IRewardHandler {
  event RewardHandled(
    address indexed eligibleRewardAsset,
    address indexed reward,
    uint256 indexed amount,
    uint256 batchTimestamp,
    DistributionType distributionType,
    bytes metadata
  );

  event Claimed(
    address indexed account,
    address indexed receiver,
    address indexed eligibleRewardAsset,
    address reward,
    uint256 amount
  );

  /**
   * @notice Checks if the account can claim.
   * @param account The account address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claimable(address account, address reward, bytes calldata metadata) external view returns (bool);

  /**
   * @notice Returns the amount of claimable rewards for the account.
   * @param account The account address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claimableAmount(address account, address reward, bytes calldata metadata) external view returns (uint256);

  /**
   * @notice Claims all of the rewards for the specified vault and reward.
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claim(address reward, bytes calldata metadata) external;

  /**
   * @notice Claims all of the rewards for the specified vault and reward, sending them to the receiver.
   * @param receiver The receiver address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claim(address receiver, address reward, bytes calldata metadata) external;

  /**
   * @notice Claims a specific amount of rewards for the specified vault and reward.
   * @dev param `amount` will be ignored.
   * @param reward The reward token address
   * @param amount The reward amount
   * @param metadata The encoded metadata
   */
  function claim(address reward, uint256 amount, bytes calldata metadata) external;

  /**
   * @notice Claims a specific amount of rewards for the specified vault and reward, sending them to the receiver.
   * @dev param `amount` will be ignored.
   * @param receiver The receiver address
   * @param reward The reward token address
   * @param amount The reward amount
   * @param metadata The encoded metadata
   */
  function claim(address receiver, address reward, uint256 amount, bytes calldata metadata) external;
}
