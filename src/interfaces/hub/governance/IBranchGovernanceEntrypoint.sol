// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBranchGovernanceEntrypoint {
  function dispatchGovernanceExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external;
}
