// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IEOLGovernor {
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256);

  function proposalThreshold() external view returns (uint256);

  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
