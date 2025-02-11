// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IManagerWithMerkleVerification {
  event ManageRootUpdated(address indexed strategist, bytes32 oldRoot, bytes32 newRoot);
  event StrategyExecutorExecuted(uint256 callsMade);

  error IManagerWithMerkleVerification__FailedToVerifyManageProof(address target, bytes targetData, uint256 value);

  function manageRoot(address strategist) external view returns (bytes32);
  function setManageRoot(address strategist, bytes32 _manageRoot) external;
  function manageVaultWithMerkleVerification(
    bytes32[][] calldata manageProofs,
    address[] calldata decodersAndSanitizers,
    address[] calldata targets,
    bytes[] calldata targetData,
    uint256[] calldata values
  ) external;
}
