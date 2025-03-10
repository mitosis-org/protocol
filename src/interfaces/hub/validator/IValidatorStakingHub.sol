// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IValidatorManager } from './IValidatorManager.sol';

/// @title IValidatorStakingHub
/// @notice Interface for the ValidatorStakingHub contract.
/// @dev This interface defines the actions that notifiers can perform to track staking.
interface IValidatorStakingHub {
  // ========== VIEWS ========== //

  function entrypoint() external view returns (IConsensusValidatorEntrypoint);

  function isNotifier(address notifier) external view returns (bool);

  function validatorTotal(address valAddr, uint48 timestamp) external view returns (uint256);
  function validatorTotalTWAB(address valAddr, uint48 timestamp) external view returns (uint256);

  function stakerTotal(address staker, uint48 timestamp) external view returns (uint256);
  function stakerTotalTWAB(address staker, uint48 timestamp) external view returns (uint256);

  function validatorStakerTotal(address valAddr, address staker, uint48 timestamp) external view returns (uint256);
  function validatorStakerTotalTWAB(address valAddr, address staker, uint48 timestamp) external view returns (uint256);

  // ========== ADMIN ACTIONS ========== //

  function addNotifier(address notifier) external;
  function removeNotifier(address notifier) external;

  // ========== NOTIFIER ACTIONS ========== //

  function notifyStake(address valAddr, address staker, uint256 amount) external;
  function notifyUnstake(address valAddr, address staker, uint256 amount) external;
  function notifyRedelegation(address fromValAddr, address toValAddr, address staker, uint256 amount) external;
}
