// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';

/// @title IValidatorManager
/// @notice Interface for the ValidatorManager contract.
/// @dev This interface defines the actions that users and validators can perform.
///
/// User Actions
/// 1. Staking (Delegate)
/// 2. Redelegate
/// 3. Unstaking (Undelegate)
///
/// Validator Actions
/// 1. Joining the validator set
/// 2. Deposit collateral
/// 3. Withdraw collateral
/// 4. Unjailing the validator
/// 5. Leaving the validator set = making it inactive, not removing anything
interface IValidatorManager {
  // ========== USER ACTIONS ========== //

  function stake(address valAddr, address recipient) external payable;
  function unstake(address valAddr, uint256 amount) external;
  function redelegate(address fromValidator, address toValidator, uint256 amount) external;

  // ========== VALIDATOR ACTIONS ========== //

  /// @param valKey The compressed 33-byte secp256k1 public key of the valAddr.
  function join(bytes calldata valKey) external payable;
  function updateOperator(address operator) external;
  function depositCollateral(address valAddr) external payable;
  function withdrawCollateral(address valAddr, uint256 amount) external;
  function unjail(address valAddr) external;

  // ========== CONTRACT MANAGEMENT ========== //

  function setEntrypoint(IConsensusValidatorEntrypoint entrypoint) external;
}
