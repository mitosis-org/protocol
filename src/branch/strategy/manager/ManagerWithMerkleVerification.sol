// SPDX-License-Identifier: MIT
// Based on https://github.com/Se7en-Seas/boring-vault
pragma solidity 0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Address } from '@openzeppelin/contracts/utils/Address.sol';

import { IStrategyExecutor } from '../../../interfaces/branch/strategy/IStrategyExecutor.sol';
import { IManagerWithMerkleVerification } from
  '../../../interfaces/branch/strategy/manager/IManagerWithMerkleVerification.sol';
import { Pausable } from '../../../lib/Pausable.sol';
import { StdError } from '../../../lib/StdError.sol';
import { ManagerWithMerkleVerificationStorageV1 } from './ManagerWithMerkleVerificationStorageV1.sol';

import { MerkleProofLib } from 'dependencies/solmate-6.8.0/src/utils/MerkleProofLib.sol'; // TODO

contract ManagerWithMerkleVerification is
  IManagerWithMerkleVerification,
  Pausable,
  Ownable2StepUpgradeable,
  ManagerWithMerkleVerificationStorageV1
{
  using Address for address;

  IStrategyExecutor public immutable strategyExecutor;

  constructor(address _strategyExecutor) initializer {
    strategyExecutor = IStrategyExecutor(_strategyExecutor);
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  function setStrategist(address strategist) external onlyOwner {
    _getStorageV1().strategist = strategist;
    emit StrategistUpdated(strategist);
  }

  function setManageRoot(address strategist, bytes32 _manageRoot) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    bytes32 oldRoot = $.manageRoot[strategist];
    $.manageRoot[strategist] = _manageRoot;
    emit ManageRootUpdated(strategist, oldRoot, _manageRoot);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function manageVaultWithMerkleVerification(
    bytes32[][] calldata manageProofs,
    address[] calldata decodersAndSanitizers,
    address[] calldata targets,
    bytes[] calldata targetData,
    uint256[] calldata values
  ) external {
    _assertNotPaused();

    StorageV1 storage $ = _getStorageV1();
    _assertOnlyStrategist($);

    uint256 targetsLength = targets.length;
    if (targetsLength != manageProofs.length) revert('ManagerWithMerkleVerification__InvalidManageProofLength()');
    if (targetsLength != targetData.length) revert('ManagerWithMerkleVerification__InvalidTargetDataLength()');
    if (targetsLength != values.length) revert('ManagerWithMerkleVerification__InvalidValuesLength()');
    if (targetsLength != decodersAndSanitizers.length) {
      revert('ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength()');
    }

    bytes32 strategistManageRoot = $.manageRoot[msg.sender];

    for (uint256 i; i < targetsLength; ++i) {
      _verifyCallData(
        strategistManageRoot, manageProofs[i], decodersAndSanitizers[i], targets[i], values[i], targetData[i]
      );
      strategyExecutor.execute(targets[i], targetData[i], values[i]);
    }

    emit StrategyExecutorExecuted(targetsLength);
  }

  function _verifyCallData(
    bytes32 currentManageRoot,
    bytes32[] calldata manageProof,
    address decoderAndSanitizer,
    address target,
    uint256 value,
    bytes calldata targetData
  ) internal view {
    // Use address decoder to get addresses in call data.
    bytes memory packedArgumentAddresses = abi.decode(decoderAndSanitizer.functionStaticCall(targetData), (bytes));

    if (
      !_verifyManageProof(
        currentManageRoot, manageProof, target, decoderAndSanitizer, value, bytes4(targetData), packedArgumentAddresses
      )
    ) {
      revert('ManagerWithMerkleVerification__FailedToVerifyManageProof(target, targetData, value)');
    }
  }

  /**
   * @notice Helper function to verify a manageProof is valid.
   */
  function _verifyManageProof(
    bytes32 root,
    bytes32[] calldata proof,
    address target,
    address decoderAndSanitizer,
    uint256 value,
    bytes4 selector,
    bytes memory packedArgumentAddresses
  ) internal pure returns (bool) {
    bool valueNonZero = value > 0;
    bytes32 leaf =
      keccak256(abi.encodePacked(decoderAndSanitizer, target, valueNonZero, selector, packedArgumentAddresses));
    return MerkleProofLib.verify(proof, root, leaf);
  }

  function _assertOnlyStrategist(StorageV1 storage $) internal view {
    require(_msgSender() == $.strategist, StdError.Unauthorized());
  }
}
