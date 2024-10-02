// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IEOLGovernor
 * @dev Interface for the EOL Governor, which manages proposal creation and governance functionality for EOL protocols.
 */
interface IEOLGovernor {
  /**
   * @notice Creates a new proposal.
   * @dev This function can only be called by authorized proposers.
   * @param targets An array of addresses that will be called if the proposal passes.
   * @param values An array of eth values to be sent with each call to the targets.
   * @param calldatas An array of call data to be sent with each call to the targets.
   * @param description A human-readable description of the proposal.
   * @return The ID of the newly created proposal.
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256);

  /**
   * @notice Returns the current proposal threshold.
   * @dev The proposal threshold is the minimum number of votes an account must have to create a proposal.
   * @return The current proposal threshold.
   */
  function proposalThreshold() external view returns (uint256);

  /**
   * @notice Checks if the contract supports a given interface.
   * @param interfaceId The interface identifier, as specified in ERC-165.
   * @return A boolean indicating whether the contract supports the interface.
   */
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
