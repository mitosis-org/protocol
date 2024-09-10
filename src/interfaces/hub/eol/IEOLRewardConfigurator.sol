// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IEOLRewardDistributor } from './IEOLRewardDistributor.sol';

enum DistributionType {
  Unspecified,
  MerkleProof,
  TWAB
}

interface IEOLRewardConfiguratorStorageV1 {
  event RewardDistributionTypeSet(
    address indexed eolVault, address indexed asset, DistributionType indexed distributionType
  );
  event DefaultDistributorSet(
    DistributionType indexed distributionType, IEOLRewardDistributor indexed rewardDistributor
  );
  event RewardDistributorRegistered(IEOLRewardDistributor indexed distributor);
  event RewardDistributorUnregistered(IEOLRewardDistributor indexed distributor);

  error IEOLRewardConfiguratorStorageV1__RewardDistributorAlreadyRegistered();
  error IEOLRewardConfiguratorStorageV1__RewardDistributorNotRegistered();
  error IEOLRewardConfiguratorStorageV1__DefaultDistributorNotSet(DistributionType);

  function rewardRatioPrecision() external pure returns (uint256);

  function distributionType(address eolVault, address asset) external view returns (DistributionType);

  function defaultDistributor(DistributionType distributionType) external view returns (IEOLRewardDistributor);

  function eolAssetHolderRewardRatio() external view returns (uint256);

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool);
}

interface IEOLRewardConfigurator is IEOLRewardConfiguratorStorageV1 {
  error IEOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed();

  function registerDistributor(IEOLRewardDistributor distributor) external;

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType) external;

  function setDefaultDistributor(IEOLRewardDistributor distributor) external;
}
