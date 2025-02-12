// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibSecp256k1 } from '../../lib/LibSecp256k1.sol';
import { StdError } from '../../lib/StdError.sol';

// TODO(thai): test codes

contract ConsensusValidatorEntrypoint is IConsensusValidatorEntrypoint, Ownable2StepUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.ConsensusValidatorEntrypoint
  struct Storage {
    mapping(address caller => bool) isPermittedCaller;
  }

  modifier onlyPermittedCaller() {
    require(_getStorage().isPermittedCaller[_msgSender()], StdError.Unauthorized());
    _;
  }

  /**
   * @notice Verifies that the given validator key is valid format which is a compressed 33-byte secp256k1 public key.
   */
  modifier verifyValkey(bytes memory valkey) {
    LibSecp256k1.verifyCmpPubkey(valkey);
    _;
  }

  /**
   * @notice Verifies that the given validator key is valid format and corresponds to the expected address.
   */
  modifier verifyValkeyWithAddress(bytes memory valkey, address expectedAddress) {
    LibSecp256k1.verifyCmpPubkeyWithAddress(valkey, expectedAddress);
    _;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.ConsensusValidatorEntrypoint';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorage() private view returns (Storage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    revert StdError.Unauthorized();
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  function initialize(address _owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(_owner);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function isPermittedCaller(address caller) external view returns (bool) {
    return _getStorage().isPermittedCaller[caller];
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  // TODO(thai): Move the logic which checks `valkey` is corresponding to `initialOperator` from here to the caller contract.
  function registerValidator(bytes calldata valkey, address initialOperator)
    external
    payable
    onlyPermittedCaller
    verifyValkeyWithAddress(valkey, initialOperator)
  {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    payable(address(0)).transfer(msg.value);

    emit MsgRegisterValidator(valkey, msg.value);
  }

  function unregisterValidator(bytes calldata valkey, uint48 unregisterAt)
    external
    onlyPermittedCaller
    verifyValkey(valkey)
  {
    emit MsgUnregisterValidator(valkey, unregisterAt);
  }

  function depositCollateral(bytes calldata valkey) external payable onlyPermittedCaller verifyValkey(valkey) {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    payable(address(0)).transfer(msg.value);

    emit MsgDepositCollateral(valkey, msg.value);
  }

  function withdrawCollateral(bytes calldata valkey, uint256 amount, address receiver, uint48 withdrawAt)
    external
    onlyPermittedCaller
    verifyValkey(valkey)
  {
    require(amount > 0, StdError.InvalidParameter('amount'));

    payable(address(0)).transfer(amount);

    emit MsgWithdrawCollateral(valkey, amount, receiver, withdrawAt);
  }

  function unjail(bytes calldata valkey) external onlyPermittedCaller verifyValkey(valkey) {
    emit MsgUnjail(valkey);
  }

  function updateExtraVotingPower(bytes calldata valkey, uint256 extraVotingPower)
    external
    onlyPermittedCaller
    verifyValkey(valkey)
  {
    emit MsgUpdateExtraVotingPower(valkey, extraVotingPower);
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function setPermittedCaller(address caller, bool isPermitted) external onlyOwner {
    _getStorage().isPermittedCaller[caller] = isPermitted;
    emit PermittedCallerSet(caller, isPermitted);
  }
}
