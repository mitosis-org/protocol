// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IValidatorManager } from './IValidatorManager.sol';

/// @title IValidatorStakingHub
/// @notice Interface for the ValidatorStakingHub contract.
/// @dev This interface defines the actions that notifiers can perform to track staking.
interface IValidatorStakingHub {
  // ========== VIEWS ========== //

  function manager() external view returns (IValidatorManager);
  function entrypoint() external view returns (IConsensusValidatorEntrypoint);

  // ========== ADMIN ACTIONS ========== //

  function addNotifier(address notifier) external;
  function removeNotifier(address notifier) external;

  // ========== NOTIFIER ACTIONS ========== //

  function notifyStake(address valAddr, address staker, uint256 amount) external;
  function notifyUnstake(address valAddr, address staker, uint256 amount) external;
  function notifyRedelegation(address fromValAddr, address toValAddr, address staker, uint256 amount) external;
}
