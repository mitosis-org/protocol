// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { EOLRewardConfiguratorStorageV1 } from './storage/EOLRewardConfiguratorStorageV1.sol';
import { DistributeType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

contract EOLRewardConfigurator is IEOLRewardConfigurator, EOLRewardConfiguratorStorageV1 {
  modifier onlyOwner() {
    _;
  }

  // View functions

  function getDistributeType(address eolVault, address asset) external view returns (DistributeType) {
    return _getStorageV1().distributeTypes[eolVault][asset];
  }

  function getDefaultDistributor(DistributeType distributeType) external view returns (IEOLRewardDistributor) {
    return _getStorageV1().defaultDistributor[distributeType];
  }

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool) {
    return _getStorageV1().isDistributorRegistered[distributor];
  }

  // Mutative functions

  function setRewardDistributeType(address eolVault, address asset, DistributeType distributeType) external onlyOwner {
    _getStorageV1().distributeTypes[eolVault][asset] = distributeType;
  }

  function setDefaultDistributor(DistributeType distributeType, IEOLRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    if (!$.isDistributorRegistered[distributor]) revert IEOLRewardConfigurator__RewardDistributorNotRegistered();
    $.defaultDistributor[distributeType] = distributor;
  }

  function registerDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    _getStorageV1().isDistributorRegistered[distributor] = true;
  }
}
