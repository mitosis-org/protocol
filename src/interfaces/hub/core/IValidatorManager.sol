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
  struct RedelegationsResponse {
    uint96 epoch;
    address fromValAddr;
    address toValAddr;
    address staker;
    uint256 amount;
  }

  function validators() external view returns (address[] memory);
  function staked(address valAddr, address staker) external view returns (uint256);
  function staked(address valAddr, address staker, uint48 timestamp) external view returns (uint256);
  function stakedTWAB(address valAddr, address staker) external view returns (uint256);
  function stakedTWAB(address valAddr, address staker, uint48 timestamp) external view returns (uint256);
  function redelegations(address toValAddr, address staker, uint96 epoch)
    external
    view
    returns (RedelegationsResponse[] memory);

  function totalDelegation(address valAddr) external view returns (uint256);
  function totalDelegation(address valAddr, uint48 timestamp) external view returns (uint256);
  function totalDelegationTWAB(address valAddr) external view returns (uint256);
  function totalDelegationTWAB(address valAddr, uint48 timestamp) external view returns (uint256);
  function totalPendingRedelegation(address valAddr) external view returns (uint256);
  function totalPendingRedelegation(address valAddr, uint96 epoch) external view returns (uint256);

  // ========== USER ACTIONS ========== //

  function stake(address valAddr, address recipient) external payable;
  function unstake(address valAddr, uint256 amount) external;
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external;
  function cancelRedelegation(address fromValAddr, address toValAddr, uint256 amount) external;

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
