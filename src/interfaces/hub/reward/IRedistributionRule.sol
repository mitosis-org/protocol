// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRedistributionRule {
  error IRedistributionRule__SourceIsNotContract(address source);
  error IRedistributionRule__SourceIsNotRegistered(address source);

  function getTotalWeight(address source) external returns (uint256 totalWeight);

  function getTotalWeights(address[] memory source) external returns (uint256[] memory totalWeights);

  function getWeight(address source, address account) external returns (uint256 weight);

  function getWeights(address source, address[] memory accounts) external returns (uint256[] memory weights);
}
