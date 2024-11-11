// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRedistributionRegistry
 * @dev Common interface for {RedistributionRegistry}.
 */
interface IRedistributionRegistry {
  event RedistributionEnabled(address indexed account);

  /**
   * @notice Returns the Mitosis contract
   */
  function mitosis() external view returns (address);

  /**
   * @notice Returns if a redistribution is enabled for `account`
   * @param account The account address
   */
  function isRedistributionEnabled(address account) external view returns (bool);

  /**
   * @notice Enables redistribution for the `msg.sender`
   */
  function enableRedistribution() external;

  function enableRedistributionByMitosis(address account) external;
}
