// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBranchGovernanceManager {
  event MITOGovernanceSet(address prevMITOGovernance, address mitoGovernance);
  event ManagerSet(address manager);
  event ManagerPhaseOver();

  function isManager(address manager) external view returns (bool);

  function setMITOGovernance(address mitoGovernance_) external;
  function finalizeManagerPhase() external;

  function dispatchExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external;
}
