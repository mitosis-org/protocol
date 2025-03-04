// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IConsensusValidatorEntrypoint {
  event PermittedCallerSet(address caller, bool isPermitted);

  event MsgRegisterValidator(bytes valkey, uint256 initialCollateralAmountGwei);
  event MsgDepositCollateral(bytes valkey, uint256 amountGwei);
  event MsgWithdrawCollateral(bytes valkey, uint256 amountGwei, address receiver, uint48 receivesAt);
  event MsgUnjail(bytes valkey);
  event MsgUpdateExtraVotingPower(bytes valkey, uint256 extraVotingPower);

  /**
   * @notice Register a validator in the consensus layer.
   * @dev Nothing happens if the validator is already registered in the consensus layer.
   * @param valkey The compressed 33-byte secp256k1 public key of the validator.
   */
  function registerValidator(bytes calldata valkey) external payable;

  /**
   * @notice Deposit collateral to the validator in the consensus layer.
   * @dev Nothing happens if the validator is not registered in the consensus layer.
   * @param valkey The compressed 33-byte secp256k1 public key of the validator.
   */
  function depositCollateral(bytes calldata valkey) external payable;

  /**
   * @notice Withdraw collateral from the validator in the consensus layer.
   * The collateral is sent to the receiver address at the specified time.
   * @dev Nothing happens if the validator is not registered in the consensus layer or has insufficient collateral.
   * @param valkey The compressed 33-byte secp256k1 public key of the validator.
   * @param amount The amount of collateral to withdraw.
   * @param receiver The address to receive the withdrawn collateral.
   * @param receivesAt The time at which the collateral will be transferred to the receiver.
   */
  function withdrawCollateral(bytes calldata valkey, uint256 amount, address receiver, uint48 receivesAt) external;

  /**
   * @notice Unjail a validator in the consensus layer.
   * @dev Nothing happens if the validator is not jailed in the consensus layer.
   * @param valkey The compressed 33-byte secp256k1 public key of the validator.
   */
  function unjail(bytes calldata valkey) external;

  /**
   * @notice Update the extra voting power of a validator in the consensus layer.
   * @dev Nothing happens if the validator is not registered in the consensus layer.
   * @param valkey The compressed 33-byte secp256k1 public key of the validator.
   * @param extraVotingPower The new extra voting power of the validator.
   */
  function updateExtraVotingPower(bytes calldata valkey, uint256 extraVotingPower) external;
}
