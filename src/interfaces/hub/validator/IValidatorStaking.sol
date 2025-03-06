// SPDX-License-Identifier: MIT
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
  event UnstakeClaimed(address indexed val, address indexed who, uint256 amount);
  event Redelegated(address indexed from, address indexed to, address indexed who, uint256 amount);

  event UnstakeCooldownUpdated(uint48 unstakeCooldown);
  event RedelegationCooldownUpdated(uint48 redelegationCooldown);

  error IValidatorStaking__NotValidator();
  error IValidatorStaking__RedelegateToSameValidator();
  error IValidatorStaking__CooldownNotPassed();

  // ========== VIEWS ========== //

  function baseAsset() external view returns (address);
  function epochFeeder() external view returns (IEpochFeeder);
  function manager() external view returns (IValidatorManager);
  function hub() external view returns (IValidatorStakingHub);
  function entrypoint() external view returns (IConsensusValidatorEntrypoint);

  function unstakeCooldown() external view returns (uint48);
  function redelegationCooldown() external view returns (uint48);

  function totalStaked(uint48 timestamp) external view returns (uint256);
  function totalUnstaking() external view returns (uint256);

  function staked(address valAddr, address staker, uint48 timestamp) external view returns (uint256);
  function stakerTotal(address staker, uint48 timestamp) external view returns (uint256);
  function validatorTotal(address valAddr, uint48 timestamp) external view returns (uint256);
  function unstaking(address valAddr, address staker, uint48 timestamp) external view returns (uint256, uint256);

  function lastRedelegationTime(address staker) external view returns (uint256);

  // ========== ACTIONS ========== //

  function stake(address valAddr, address recipient, uint256 amount) external payable;
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256);
  function claimUnstake(address valAddr, address receiver) external returns (uint256);
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external;

  // ========== ADMIN ACTIONS ========== //

  function setUnstakeCooldown(uint48 unstakeCooldown_) external;
  function setRedelegationCooldown(uint48 redelegationCooldown_) external;
}
