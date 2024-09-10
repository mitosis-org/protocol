// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, DistributionType } from '../reward/IRewardDistributor.sol';

interface IEOLRewardConfigurator {
  error IEOLRewardConfigurator__RewardDistributorAlreadyRegistered();
  error IEOLRewardConfigurator__RewardDistributorNotRegistered();

  // TODO(ray): Could be configurable.
  function rewardRatioPrecision() external pure returns (uint256);

  function getDistributionType(address eolVault, address asset) external view returns (DistributionType);

  function getDefaultDistributor(DistributionType distributionType) external view returns (IRewardDistributor);

  function getEOLAssetHolderRewardRatio() external view returns (uint256);

  function isDistributorRegistered(IRewardDistributor distributor) external view returns (bool);

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType) external;

  function setDefaultDistributor(IRewardDistributor distributor) external;

  function registerDistributor(IRewardDistributor distributor) external;
}
