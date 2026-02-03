// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IValidatorStaking } from './IValidatorStaking.sol';
import { ITMITO } from '../../../hub/lst/external/ITMITO.sol';

/// @title IValidatorStakingMigration
/// @notice Interface for the ValidatorStakingMigration contract.
/// @dev Enables migration of staking between ValidatorStaking_MITO and ValidatorStaking_TMITO.
interface IValidatorStakingMigration {
  // =========================== ERRORS =========================== //

  error ValidatorStakingMigration__LockupNotEnded();
  error ValidatorStakingMigration__NotMigrationAgent();

  // =========================== EVENTS =========================== //

  event MigrationStarted(address indexed user, address indexed valAddr, uint256 amount);
  event MigrationCompleted(address indexed recipient, address indexed valAddr, uint256 amount);
  event InstantMigrationCompleted(
    address indexed user, address indexed valAddr, address indexed recipient, uint256 amount
  );

  // =========================== EXTERNAL DEPENDENCIES =========================== //

  function tmitoValidatorStaking() external view returns (IValidatorStaking);
  function mitoValidatorStaking() external view returns (IValidatorStaking);
  function tMITO() external view returns (ITMITO);

  // =========================== MIGRATION =========================== //

  /// @notice Instant migration: TMITO -> MITO in a single tx (bypasses unstake cooldown).
  /// @dev Requires: 1) User approved this contract on tmitoValidatorStaking.approveStakingOwnership
  ///                2) ValidatorStaking_TMITO owner set this contract as migrationAgent
  /// @param valAddr Validator address
  /// @param amount Amount of TMITO staking to migrate
  /// @param recipient Address to receive MITO staking
  /// @return mitoAmount The amount of MITO staked for recipient
  function migrateFromTMITOToMITO(address valAddr, uint256 amount, address recipient)
    external
    returns (uint256 mitoAmount);
}
