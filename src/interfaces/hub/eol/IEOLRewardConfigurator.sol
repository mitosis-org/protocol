// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEOLRewardDistributor } from './IEOLRewardDistributor.sol';

enum DistributeType {
  Unspecified,
  MerkleProof,
  TWAB
}

interface IEOLRewardConfigurator {
  error IEOLRewardConfigurator__RewardDistributorNotRegistered();

  function getDistributeType(address eolVault, address asset) external view returns (DistributeType);

  function getDefaultDistributor(DistributeType distributeType) external view returns (IEOLRewardDistributor);

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool);

  function setRewardDistributeType(address eolVault, address asset, DistributeType distributeType) external;

  function setDefaultDistributor(DistributeType distributeType, IEOLRewardDistributor distributor) external;

  function registerDistributor(IEOLRewardDistributor distributor) external;
}
