// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from '../reward/IRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../reward/IRewardDistributor.sol';

interface IEOLRewardConfigurator is IRewardConfigurator {
  event RewardDistributionTypeSet(
    address indexed eolVault, address indexed asset, DistributionType indexed distributionType
  );
  event DefaultDistributorSet(DistributionType indexed distributionType, IRewardDistributor indexed rewardDistributor);
  event RewardDistributorRegistered(IRewardDistributor indexed distributor);
  event RewardDistributorUnregistered(IRewardDistributor indexed distributor);

  error IEOLRewardConfigurator__DefaultDistributorNotSet(DistributionType);
  error IEOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed();
  error IEOLRewardConfigurator__InvalidRewardConfigurator();

  error IEOLRewardConfigurator__RewardDistributorAlreadyRegistered();
  error IEOLRewardConfigurator__RewardDistributorNotRegistered();

  function getDistributionType(address eolVault, address asset) external view returns (DistributionType);

  function getDefaultDistributor(DistributionType distributionType) external view returns (IRewardDistributor);

  function getEOLAssetHolderRewardRatio() external view returns (uint256);

  function isDistributorRegistered(IRewardDistributor distributor) external view returns (bool);

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType) external;

  function setDefaultDistributor(IRewardDistributor distributor) external;

  function registerDistributor(IRewardDistributor distributor) external;
}
