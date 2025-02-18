// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from './IEpochFeeder.sol';

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
  struct ValidatorInfoResponse {
    address validator;
    address operator;
    address rewardRecipient;
    uint256 commissionRate;
    bytes metadata;
  }

  struct RedelegationsResponse {
    uint96 epoch;
    address fromValAddr;
    address toValAddr;
    address staker;
    uint256 amount;
  }

  struct CreateValidatorRequest {
    uint256 commissionRate; // bp ex) 10000 = 100%
    bytes metadata;
  }

  struct UpdateRewardConfigRequest {
    uint256 commissionRate; // bp ex) 10000 = 100%
  }

  struct SetGlobalValidatorConfigRequest {
    uint256 minimumCommissionRate; // bp ex) 10000 = 100%
    uint96 commissionRateUpdateDelay; // in epoch
  }

  function validatorCount() external view returns (uint256);
  function validatorAt(uint256 index) external view returns (address);
  function isValidator(address valAddr) external view returns (bool);
  function validatorInfo(address valAddr) external view returns (ValidatorInfoResponse memory);

  function stakedValidators(address staker) external view returns (address[] memory);
  function isStakedValidator(address valAddr, address staker) external view returns (bool);

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

  // validator actions
  /// @param valKey The compressed 33-byte secp256k1 public key of the valAddr.
  function createValidator(bytes calldata valKey, CreateValidatorRequest calldata request) external payable;
  function updateOperator(address operator) external; // sender must be valAddr

  // operator actions
  function depositCollateral(address valAddr) external payable;
  function withdrawCollateral(address valAddr, uint256 amount) external;
  function unjailValidator(address valAddr) external;

  // validator configurations
  function updateRewardRecipient(address valAddr, address rewardRecipient) external;
  function updateMetadata(address valAddr, bytes calldata metadata) external;
  function updateRewardConfig(address valAddr, UpdateRewardConfigRequest calldata request) external;

  // ========== CONTRACT MANAGEMENT ========== //

  function setGlobalValidatorConfig(SetGlobalValidatorConfigRequest calldata request) external;
  function setEpochFeeder(IEpochFeeder epochFeeder) external;
  function setEntrypoint(IConsensusValidatorEntrypoint entrypoint) external;
}
