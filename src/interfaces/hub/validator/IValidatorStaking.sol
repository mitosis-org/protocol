// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from './IEpochFeeder.sol';
import { IValidatorManager } from './IValidatorManager.sol';
import { IValidatorStakingHub } from './IValidatorStakingHub.sol';

/// @title IValidatorStaking
/// @notice Interface for the ValidatorStaking contract.
/// @dev This interface defines the actions that users and validators can perform.
interface IValidatorStaking {
  event Staked(address indexed val, address indexed who, address indexed to, uint256 amount);
  event UnstakeRequested(address indexed val, address indexed who, address indexed to, uint256 amount, uint256 reqId);
  event UnstakeClaimed(address indexed who, uint256 amount, uint256 reqIdFrom, uint256 reqIdTo);
  event Redelegated(address indexed from, address indexed to, address indexed who, uint256 amount);

  event StakingOwnershipApproved(address indexed val, address indexed from, address indexed spender, uint256 amount);
  event StakingOwnershipTransferred(address indexed val, address indexed from, address indexed to, uint256 amount);

  event MinimumStakingAmountSet(uint256 previousAmount, uint256 newAmount);
  event MinimumUnstakingAmountSet(uint256 previousAmount, uint256 newAmount);

  event UnstakeCooldownUpdated(uint48 unstakeCooldown);
  event RedelegationCooldownUpdated(uint48 redelegationCooldown);
  event MigrationAgentSet(address indexed previousAgent, address indexed newAgent);

  error IValidatorStaking__NotValidator(address valAddr);
  error IValidatorStaking__RedelegateToSameValidator(address valAddr);
  error IValidatorStaking__CooldownNotPassed(uint48 lastTime, uint48 currentTime, uint48 requiredCooldown);
  error IValidatorStaking__InsufficientMinimumAmount(uint256 minAmount);
  error IValidatorStaking__InsufficientStakedAmount(uint256 requested, uint256 available);

  // ========== VIEWS ========== //

  function baseAsset() external view returns (address);
  function manager() external view returns (IValidatorManager);
  function hub() external view returns (IValidatorStakingHub);

  function minStakingAmount() external view returns (uint256);
  function minUnstakingAmount() external view returns (uint256);

  function unstakeCooldown() external view returns (uint48);
  function redelegationCooldown() external view returns (uint48);

  function totalStaked(uint48 timestamp) external view returns (uint256);
  function totalUnstaking(uint48 timestamp) external view returns (uint256);

  /**
   * @notice Returns the amount of staked tokens for a validator.
   * @param valAddr The address of the validator.
   * @param staker The address of the staker.
   * @param timestamp The timestamp to check.
   * @return staked The amount of staked tokens.
   */
  function staked(address valAddr, address staker, uint48 timestamp) external view returns (uint256);

  /**
   * @notice Returns the total amount of staked tokens for a staker.
   * @param staker The address of the staker.
   * @param timestamp The timestamp to check.
   * @return stakerTotal The total amount of staked tokens.
   */
  function stakerTotal(address staker, uint48 timestamp) external view returns (uint256);

  /**
   * @notice Returns the total amount of staked tokens for a validator.
   * @param valAddr The address of the validator.
   * @param timestamp The timestamp to check.
   * @return validatorTotal The total amount of staked tokens.
   */
  function validatorTotal(address valAddr, uint48 timestamp) external view returns (uint256);

  /**
   * @notice Returns the total unstaking amount and the amount that can be claimed.
   * @param staker The address of the staker.
   * @param timestamp The timestamp to check.
   * @return totalUnstaking The total unstaking amount.
   * @return claimable The amount that can be claimed.
   */
  function unstaking(address staker, uint48 timestamp) external view returns (uint256, uint256);

  /**
   * @notice Returns the offset of the unstaking queue for a staker.
   * @param staker The address of the staker.
   * @return offset The offset of the unstaking queue.
   */
  function unstakingQueueOffset(address staker) external view returns (uint256);

  /**
   * @notice Returns the size of the unstaking queue for a staker.
   * @param staker The address of the staker.
   * @return size The size of the unstaking queue.
   */
  function unstakingQueueSize(address staker) external view returns (uint256);

  /**
   * @notice Returns the unstaking request at a specific index for a staker.
   * @param staker The address of the staker.
   * @param pos The position in the queue.
   * @return timestamp The timestamp of the request.
   * @return amount The amount requested.
   */
  function unstakingQueueRequestByIndex(address staker, uint32 pos) external view returns (uint48, uint208);

  /**
   * @notice Returns the unstaking request at a specific time for a staker.
   * @param staker The address of the staker.
   * @param time The timestamp to look up.
   * @return timestamp The timestamp of the request.
   * @return amount The amount requested.
   */
  function unstakingQueueRequestByTime(address staker, uint48 time) external view returns (uint48, uint208);

  /**
   * @notice Returns the last time a staker redelegated.
   * @param staker The address of the staker.
   * @param valAddr The address of the validator.
   * @return lastRedelegationTime The last time a staker redelegated.
   */
  function lastRedelegationTime(address staker, address valAddr) external view returns (uint256);

  // ========== ACTIONS ========== //

  /**
   * @notice Stakes tokens for a validator.
   * @param valAddr The address of the validator.
   * @param recipient The address of the recipient.
   * @param amount The amount of tokens to stake.
   * @return The amount of tokens staked.
   */
  function stake(address valAddr, address recipient, uint256 amount) external payable returns (uint256);

  /**
   * @notice Requests to unstake tokens from a validator.
   * @param valAddr The address of the validator.
   * @param receiver The address of the receiver.
   * @param amount The amount of tokens to unstake.
   * @return reqId The request ID.
   */
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256);

  /**
   * @notice Claims unstaked tokens from a validator.
   * @param receiver The address of the receiver.
   * @return The amount of tokens claimed.
   */
  function claimUnstake(address receiver) external returns (uint256);

  /**
   * @notice Redelegates tokens from one validator to another.
   * @param fromValAddr The address of the validator to redelegate from.
   * @param toValAddr The address of the validator to redelegate to.
   * @param amount The amount of tokens to redelegate.
   * @return amount The amount of tokens redelegated.
   */
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external returns (uint256);

  /**
   * @notice Returns the amount of staking ownership that a spender is allowed to transfer from an owner.
   * @param valAddr The address of the validator where tokens are staked.
   * @param owner The address that owns the staked tokens.
   * @param spender The address that can transfer staking ownership on behalf of the owner.
   * @return The amount of staked tokens the spender is approved to transfer.
   */
  function stakingAllowance(address valAddr, address owner, address spender) external view returns (uint256);

  /**
   * @notice Approves a spender to transfer staking ownership on behalf of the caller.
   * @dev Similar to ERC20 approve pattern, but for staked tokens with a specific validator.
   * @param valAddr The address of the validator where tokens are staked.
   * @param spender The address being approved to transfer staking ownership.
   * @param amount The amount of staked tokens the spender is approved to transfer.
   */
  function approveStakingOwnership(address valAddr, address spender, uint256 amount) external;

  /**
   * @notice Transfers staking ownership from one address to another using allowance.
   * @dev Caller must have sufficient allowance from the 'from' address for the specified validator.
   *      Similar to ERC20 transferFrom pattern, but for staked tokens.
   * @param valAddr The address of the validator where tokens are staked.
   * @param from The address to transfer staking ownership from (must have approved the caller).
   * @param to The address to transfer staking ownership to.
   * @param amount The amount of staked tokens to transfer ownership of.
   * @return The actual amount of staking ownership transferred.
   */
  function transferStakingOwnershipFrom(address valAddr, address from, address to, uint256 amount)
    external
    returns (uint256);

  // ========== ADMIN ACTIONS ========== //

  function setMinStakingAmount(uint256 minAmount) external;
  function setMinUnstakingAmount(uint256 minAmount) external;

  function setUnstakeCooldown(uint48 unstakeCooldown_) external;
  function setRedelegationCooldown(uint48 redelegationCooldown_) external;

  // ========== MIGRATION ========== //

  function setMigrationAgent(address agent) external;
  function migrationAgent() external view returns (address);

  /**
   * @notice Claims unstaked tokens immediately, bypassing cooldown. Only callable by migration agent.
   */
  function claimUnstakeForMigration() external returns (uint256);
}
