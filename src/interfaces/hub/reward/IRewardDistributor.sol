// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardHandler } from './IRewardHandler.sol';

/**
 * @title IRewardDistributor
 * @notice Common interface for distributor of rewards.
 */
interface IRewardDistributor is IRewardHandler {
  event RewardHandled(
    address indexed eolVault,
    address indexed reward,
    uint256 indexed amount,
    DistributionType distributionType,
    bytes metadata,
    bytes extraData
  );
}
