// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEOLRewardDistributor } from './IEOLRewardDistributor.sol';

enum DistributionType {
  Unspecified,
  MerkleProof,
  TWAB
}

interface IEOLRewardConfigurator {
  error IEOLRewardConfigurator__RewardDistributorAlreadyRegistered();
  error IEOLRewardConfigurator__RewardDistributorNotRegistered();

  // TODO(ray): Could be configurable.
  function rewardRatioPrecision() external pure returns (uint256);

  function getDistributionType(address eolVault, address asset) external view returns (DistributionType);

  function getDefaultDistributor(DistributionType distributionType) external view returns (IEOLRewardDistributor);

  function getEOLAssetHolderRewardRatio() external view returns (uint256);

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool);

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType) external;

  function setDefaultDistributor(DistributionType distributionType, IEOLRewardDistributor distributor) external;

  function registerDistributor(IEOLRewardDistributor distributor) external;
}
