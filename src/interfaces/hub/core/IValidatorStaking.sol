// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IEpochFeeder } from './IEpochFeeder.sol';
import { IValidatorManager } from './IValidatorManager.sol';

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

  error NotValidator();
  error RedelegateToSameValidator();
  error CooldownNotPassed();

  // ========== VIEWS ========== //

  function epochFeeder() external view returns (IEpochFeeder);
  function registry() external view returns (IValidatorManager);

  function unstakeCooldown() external view returns (uint48);
  function redelegationCooldown() external view returns (uint48);

  function totalStaked() external view returns (uint256);
  function totalUnstaking() external view returns (uint256);

  function staked(address valAddr, address staker) external view returns (uint256);
  function stakedAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256);
  function stakedTWAB(address valAddr, address staker) external view returns (uint256);
  function stakedTWABAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256);

  function unstaking(address valAddr, address staker) external view returns (uint256, uint256);
  function unstakingAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256, uint256);

  function totalDelegation(address valAddr) external view returns (uint256);
  function totalDelegationAt(address valAddr, uint48 timestamp) external view returns (uint256);
  function totalDelegationTWAB(address valAddr) external view returns (uint256);
  function totalDelegationTWABAt(address valAddr, uint48 timestamp) external view returns (uint256);

  function lastRedelegationTime(address staker) external view returns (uint256);

  // ========== ACTIONS ========== //

  function stake(address valAddr, address recipient) external payable;
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256);
  function claimUnstake(address valAddr, address receiver) external returns (uint256);
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external;

  // ========== ADMIN ACTIONS ========== //

  function setUnstakeCooldown(uint48 unstakeCooldown_) external;
  function setRedelegationCooldown(uint48 redelegationCooldown_) external;
}
