// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBranchGovernanceManager {
  event ExecutorSet(address executor);

  function isExecutor(address account) external view returns (bool);

  function dispatchExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external;
}
