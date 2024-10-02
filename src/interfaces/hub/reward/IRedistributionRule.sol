// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRedistributionRule
 * @notice Common interface for RedistributionRules
 * @dev You might define your own redistribution rule if you have complex redistribution logic or need to apply custom rules
 */
interface IRedistributionRule {
  /**
   * @notice Error thrown when the source address is not a contract.
   * @param source The address that was expected to be a contract.
   */
  error IRedistributionRule__SourceIsNotContract(address source);

  /**
   * @notice Error thrown when the source is not registered.
   * @param source The address of the unregistered source.
   */
  error IRedistributionRule__SourceIsNotRegistered(address source);

  /**
   * @notice Returns the total distribution weight of the source
   * @param source The source address
   * @return totalWeight The total distribution weight of the source
   */
  function getTotalWeight(address source) external returns (uint256 totalWeight);

  /**
   * @notice Returns the total distribution weights of the sources
   * @param source The source addresses
   * @return totalWeights The total distribution weights of the sources
   */
  function getTotalWeights(address[] memory source) external returns (uint256[] memory totalWeights);

  /**
   * @notice Returns the distribution weight of the account
   * @param source The source address
   * @param account The account address
   * @return weight The distribution weight of the account
   */
  function getWeight(address source, address account) external returns (uint256 weight);

  /**
   * @notice Returns the distribution weights of the accounts
   * @param source The source address
   * @param accounts The account addresses
   * @return weights The distribution weights of the accounts
   */
  function getWeights(address source, address[] memory accounts) external returns (uint256[] memory weights);
}
