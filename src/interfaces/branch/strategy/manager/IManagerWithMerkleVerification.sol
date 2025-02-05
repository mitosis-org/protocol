// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IManagerWithMerkleVerification {
  event StrategistUpdated(address indexed strategist);
  event ManageRootUpdated(address indexed strategist, bytes32 oldRoot, bytes32 newRoot);
  event StrategyExecutorExecuted(uint256 callsMade);
}
