// SPDX-License-Identifier: MIT
// Based on https://github.com/Se7en-Seas/boring-vault
pragma solidity ^0.8.28;

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

  constructor() initializer { }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  function strategyExecutor(address protocolVault) external view returns (address) {
    return address(_getStorageV1().manageData[protocolVault].strategyExecutor);
  }

  function manageRoot(address protocolVault, address strategist) external view returns (bytes32) {
    return _getStorageV1().manageData[protocolVault].root[strategist];
  }

  function setStrategyExecutor(address protocolVault, address strategyExecutor_) external onlyOwner {
    ManageData storage manageData = _getStorageV1().manageData[protocolVault];
    address oldStrategyExecutor = address(manageData.strategyExecutor);
    manageData.strategyExecutor = IStrategyExecutor(strategyExecutor_);
    emit StrategyExecutorUpdated(protocolVault, oldStrategyExecutor, strategyExecutor_);
  }

  function setManageRoot(address protocolVault, address strategist, bytes32 _manageRoot) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    require(
      address($.manageData[protocolVault].strategyExecutor) != address(0),
      IManagerWithMerkleVerification__StrategyExecutorNotSet(protocolVault)
    );

    bytes32 oldRoot = $.manageData[protocolVault].root[strategist];
    $.manageData[protocolVault].root[strategist] = _manageRoot;
    emit ManageRootUpdated(protocolVault, strategist, oldRoot, _manageRoot);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function manageVaultWithMerkleVerification(
    address protocolVault,
    bytes32[][] calldata manageProofs,
    address[] calldata decodersAndSanitizers,
    address[] calldata targets,
    bytes[] calldata targetData,
    uint256[] calldata values
  ) external {
    _assertNotPaused();

    StorageV1 storage $ = _getStorageV1();

    uint256 targetsLength = targets.length;
    if (targetsLength != manageProofs.length) revert('ManagerWithMerkleVerification__InvalidManageProofLength()');
    if (targetsLength != targetData.length) revert('ManagerWithMerkleVerification__InvalidTargetDataLength()');
    if (targetsLength != values.length) revert('ManagerWithMerkleVerification__InvalidValuesLength()');
    if (targetsLength != decodersAndSanitizers.length) {
      revert('ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength()');
    }

    ManageData storage manageData = $.manageData[protocolVault];

    require(
      address(manageData.strategyExecutor) != address(0),
      IManagerWithMerkleVerification__StrategyExecutorNotSet(protocolVault)
    );

    bytes32 strategistManageRoot = manageData.root[msg.sender];
    require(strategistManageRoot != 0, StdError.NotFound('manageProof'));

    for (uint256 i; i < targetsLength; ++i) {
      _verifyCallData(
        strategistManageRoot, manageProofs[i], decodersAndSanitizers[i], targets[i], values[i], targetData[i]
      );
      manageData.strategyExecutor.execute(targets[i], targetData[i], values[i]);
    }

    emit StrategyExecutorExecuted(protocolVault, address(manageData.strategyExecutor), targetsLength);
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
      revert IManagerWithMerkleVerification.IManagerWithMerkleVerification__FailedToVerifyManageProof(
        target, targetData, value
      );
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
}
