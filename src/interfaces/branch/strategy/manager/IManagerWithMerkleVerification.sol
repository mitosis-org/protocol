// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IManagerWithMerkleVerification {
  event StrategyExecutorUpdated(address indexed protocolVault, address oldStategyExecutor, address newStrategyExecutor);
  event ManageRootUpdated(address indexed protocolVault, address indexed strategist, bytes32 oldRoot, bytes32 newRoot);
  event StrategyExecutorExecuted(address indexed protocolVault, address indexed strategyExecutor, uint256 callsMade);

  error IManagerWithMerkleVerification__FailedToVerifyManageProof(address target, bytes targetData, uint256 value);
  error IManagerWithMerkleVerification__StrategyExecutorNotSet(address protocolVault);

  function strategyExecutor(address protocolVault) external view returns (address);
  function manageRoot(address protocolVault, address strategist) external view returns (bytes32);
  function setStrategyExecutor(address protocolVault, address strategyExecutor) external;
  function setManageRoot(address protocolVault, address strategist, bytes32 _manageRoot) external;
  function manageVaultWithMerkleVerification(
    address protocolVault,
    bytes32[][] calldata manageProofs,
    address[] calldata decodersAndSanitizers,
    address[] calldata targets,
    bytes[] calldata targetData,
    uint256[] calldata values
  ) external;
}
