// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor } from './IRewardDistributor.sol';

/**
 * @title ITWABRewardDistributorStorageV1
 * @notice Interface definition for the TWABRewardDistributorStorageV1
 */
interface ITWABRewardDistributorStorageV1 {
  event TWABPeriodSet(uint48 indexed period);
  event RewardPrecisionSet(uint256 indexed precision);
  event BatchPeriodSetUnsafe(uint48 indexed batchPeriod);
  event RedistributionRegistrySet(address indexed registry);

  /**
   * @notice Error thrown when attempting to set a zero TWAB period.
   */
  error ITWABRewardDistributorStorageV1__ZeroPeriod();

  /**
   * @notice Returns the batch period.
   */
  function batchPeriod() external view returns (uint48);

  /**
   * @notice Returns the current TWAB period.
   */
  function twabPeriod() external view returns (uint48);

  /**
   * @notice Returns the reward precision.
   */
  function rewardPrecision() external view returns (uint256);
}

/**
 * @title ITWABRewardDistributor
 * @notice Interface for the TWAB reward distributor
 */
interface ITWABRewardDistributor is IRewardDistributor, ITWABRewardDistributorStorageV1 {
  /**
   * @notice Event emitted when rewards are claimed.
   * @param eolVault The EOL Vault address.
   * @param account The account address.
   * @param receiver The receiver address.
   * @param reward The reward token address.
   * @param amount The amount of reward claimed.
   * @param startBatchTimestamp The start batch timestamp. (inclusive)
   * @param endBatchTimestamp The end batch timestamp. (inclusive)
   */
  event Claimed(
    address indexed eolVault,
    address indexed account,
    address indexed receiver,
    address reward,
    uint256 amount,
    uint48 startBatchTimestamp,
    uint48 endBatchTimestamp
  );

  /**
   * @notice Error thrown when there's insufficient reward for distribution.
   */
  error ITWABRewardDistributor__InsufficientReward();

  /**
   * @notice Error thrown when a redistribution is enabled.
   */
  error ITWABRewardDistributor__RedistributionEnabled();

  /**
   * @notice Error thrown when a redistribution is disabled.
   */
  error ITWABRewardDistributor__RedistributionDisabled();

  /**
   * @notice Returns the first batch timestamp for a given EOL Vault and reward.
   * @param eolVault The address of the EOL Vault contract.
   * @param reward The address of the reward token.
   */
  function getFirstBatchTimestamp(address eolVault, address reward) external view returns (uint48);

  /**
   * @notice Returns the last claimed batch timestamp for a given EOL Vault, reward and account.
   * @param eolVault The address of the EOL Vault contract.
   * @param account The address of the account.
   * @param reward The address of the reward token.
   */
  function getLastClaimedBatchTimestamp(address eolVault, address account, address reward)
    external
    view
    returns (uint48);

  /**
   * @notice Returns the last finalized batch timestamp for a given EOL Vault.
   * @param eolVault The address of the EOL Vault contract.
   */
  function getLastFinalizedBatchTimestamp(address eolVault) external view returns (uint48);

  /**
   * @notice Checks if the account can claim for the given batch timestamp.
   * @param eolVault The EOL Vault address
   * @param account The account address
   * @param reward The reward token address
   * @param batchTimestamp The batch timestamp of the rewards
   */
  function isClaimableBatch(address eolVault, address account, address reward, uint48 batchTimestamp)
    external
    view
    returns (bool);

  /**
   * @notice Returns the amount of claimable rewards for the given batch timestamp.
   * @param eolVault The EOL Vault address
   * @param account The account address
   * @param reward The reward token address
   * @param batchTimestamp The batch timestamp of the rewards
   */
  function claimableAmountForBatch(address eolVault, address account, address reward, uint48 batchTimestamp)
    external
    view
    returns (uint256);

  /**
   * @notice Returns the total claimable amount for all batch timestamps to the specified timestamp.
   * @param eolVault The address of the EOL Vault contract.
   * @param account The address of the account.
   * @param reward The address of the reward token.
   * @param toTimestamp The batch timestamp up to which (inclusive) to claim rewards.
   */
  function claimableAmount(address eolVault, address account, address reward, uint48 toTimestamp)
    external
    view
    returns (uint256);

  /**
   * @notice Claims rewards for all batch timestamps to the specified timestamp.
   * @param eolVault The address of the EOL Vault contract.
   * @param receiver The address of the receiver.
   * @param reward The address of the reward token.
   * @param toTimestamp The batch timestamp up to which (inclusive) to claim rewards.
   * @return claimedAmount The total amount of rewards claimed.
   */
  function claim(address eolVault, address receiver, address reward, uint48 toTimestamp)
    external
    returns (uint256 claimedAmount);

  /**
   * @notice Similar to `claim` but for multiple rewards.
   */
  function claimMultiple(address eolVault, address receiver, address[] calldata rewards, uint48 toTimestamp)
    external
    returns (uint256[] memory claimedAmounts);

  /**
   * @notice Similar to `claimMultiple` but for multiple EOL Vaults.
   */
  function claimBatch(address[] calldata eolVaults, address receiver, address[][] calldata rewards, uint48 toTimestamp)
    external
    returns (uint256[][] memory claimedAmounts);

  /**
   * @notice Claims rewards for all batch timestamps to the specified timestamp for a redistribution.
   * @param account The address of the account.
   * @param eolVault The address of the EOL Vault contract.
   * @param reward The address of the reward token.
   * @param toTimestamp The batch timestamp up to which (inclusive) to claim rewards.
   * @return claimedAmount The total amount of rewards claimed.
   */
  function claimForRedistribution(address account, address eolVault, address reward, uint48 toTimestamp)
    external
    returns (uint256 claimedAmount);
}
