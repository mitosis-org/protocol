// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IGovernanceExecutor {
  event ExecutionDispatched(address[] targets, bytes[] data, uint256[] values, bytes[] result);

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values) external;
}
