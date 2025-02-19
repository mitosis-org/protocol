// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from './IEpochFeeder.sol';

/// @title IValidatorRegistry
/// @notice Interface for the ValidatorRegistry contract.
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
interface IValidatorRegistry {
  struct GlobalValidatorConfigResponse {
    uint256 initialValidatorDeposit;
    uint256 unstakeCooldown;
    uint256 redelegationCooldown;
    uint256 collateralWithdrawalDelay;
    uint256 minimumCommissionRate;
    uint96 commissionRateUpdateDelay;
  }

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
    uint256 initialValidatorDeposit; // used on creation of the validator
    uint256 unstakeCooldown; // in seconds
    uint256 redelegationCooldown; // in seconds
    uint256 collateralWithdrawalDelay; // in seconds
    uint256 minimumCommissionRate; // bp ex) 10000 = 100%
    uint96 commissionRateUpdateDelay; // in epoch
  }

  event ValidatorCreated(address indexed valAddr, bytes valKey);
  event CollateralDeposited(address indexed valAddr, uint256 amount);
  event CollateralWithdrawn(address indexed valAddr, uint256 amount);
  event ValidatorUnjailed(address indexed valAddr);
  event OperatorUpdated(address indexed valAddr, address indexed operator);
  event RewardRecipientUpdated(address indexed valAddr, address indexed operator, address indexed rewardRecipient);
  event MetadataUpdated(address indexed valAddr, address indexed operator, bytes metadata);
  event RewardConfigUpdated(address indexed valAddr, address indexed operator);

  event GlobalValidatorConfigUpdated();
  event EpochFeederUpdated(IEpochFeeder indexed epochFeeder);
  event EntrypointUpdated(IConsensusValidatorEntrypoint indexed entrypoint);

  // ========== VIEWS ========== //

  function MAX_COMMISSION_RATE() external view returns (uint256);

  function entrypoint() external view returns (IConsensusValidatorEntrypoint);
  function epochFeeder() external view returns (IEpochFeeder);
  function globalValidatorConfig() external view returns (GlobalValidatorConfigResponse memory);

  function validatorCount() external view returns (uint256);
  function validatorAt(uint256 index) external view returns (address);
  function isValidator(address valAddr) external view returns (bool);

  function validatorInfo(address valAddr) external view returns (ValidatorInfoResponse memory);
  function validatorInfoAt(uint96 epoch, address valAddr) external view returns (ValidatorInfoResponse memory);

  // ========== VALIDATOR ACTIONS ========== //

  // validator actions
  /// @param valKey The compressed 33-byte secp256k1 public key of the valAddr.
  function createValidator(bytes calldata valKey, CreateValidatorRequest calldata request) external payable;
  function updateOperator(address operator) external; // sender must be valAddr

  // operator actions
  function depositCollateral(address valAddr) external payable;
  function withdrawCollateral(address valAddr, address recipient, uint256 amount) external;
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
