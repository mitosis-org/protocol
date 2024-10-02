// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRedistributionRule
 * @dev Interface for defining redistribution rules for rewards.
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
   * @notice Gets the total weight for a given source.
   * @param source The address of the source contract.
   * @return totalWeight The total weight for the source.
   */
  function getTotalWeight(address source) external returns (uint256 totalWeight);

  /**
   * @notice Gets the total weights for multiple sources.
   * @param source An array of source contract addresses.
   * @return totalWeights An array of total weights corresponding to each source.
   */
  function getTotalWeights(address[] memory source) external returns (uint256[] memory totalWeights);

  /**
   * @notice Gets the weight for a specific account from a given source.
   * @param source The address of the source contract.
   * @param account The address of the account to get the weight for.
   * @return weight The weight of the account for the given source.
   */
  function getWeight(address source, address account) external returns (uint256 weight);

  /**
   * @notice Gets the weights for multiple accounts from a given source.
   * @param source The address of the source contract.
   * @param accounts An array of account addresses to get weights for.
   * @return weights An array of weights corresponding to each account.
   */
  function getWeights(address source, address[] memory accounts) external returns (uint256[] memory weights);
}
