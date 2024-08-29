// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { DistributeType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { EOLRewardConfiguratorStorageV1 } from './storage/EOLRewardConfiguratorStorageV1.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';

contract EOLRewardConfigurator is IEOLRewardConfigurator, Ownable2StepUpgradeable, EOLRewardConfiguratorStorageV1 {
  event RewardDistributeTypeSet(address indexed eolVault, address indexed asset, DistributeType indexed distributeType);
  event DefaultDistributorSet(DistributeType indexed distributeType, IEOLRewardDistributor indexed rewardDistributor);
  event RewardDistributorRegistered(IEOLRewardDistributor indexed distributor);
  event RewardDistributorUnregistered(IEOLRewardDistributor indexed distributor);

  error EOLRewardConfigurator__DefaultDistributorNotSet(DistributeType);
  error EOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed();

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  function getDistributeType(address eolVault, address asset) external view returns (DistributeType) {
    return _getStorageV1().distributeTypes[eolVault][asset];
  }

  function getDefaultDistributor(DistributeType distributeType) external view returns (IEOLRewardDistributor) {
    return _getStorageV1().defaultDistributor[distributeType];
  }

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool) {
    return _getStorageV1().distributorRegistry[distributor];
  }

  // Mutative functions

  function setRewardDistributeType(address eolVault, address asset, DistributeType distributeType) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDefaultDistributorSet($, distributeType);

    $.distributeTypes[eolVault][asset] = distributeType;
    emit RewardDistributeTypeSet(eolVault, asset, distributeType);
  }

  function setDefaultDistributor(DistributeType distributeType, IEOLRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegisered($, distributor);

    $.defaultDistributor[distributeType] = distributor;
    emit DefaultDistributorSet(distributeType, distributor);
  }

  function registerDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    _getStorageV1().distributorRegistry[distributor] = true;
    emit RewardDistributorRegistered(distributor);
  }

  function unregisterDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertNotDefaultDistributor($, distributor);

    $.distributorRegistry[distributor] = false;
    emit RewardDistributorUnregistered(distributor);
  }

  function _assertDefaultDistributorSet(StorageV1 storage $, DistributeType distributeType) internal view {
    if (address($.defaultDistributor[distributeType]) == address(0)) {
      revert EOLRewardConfigurator__DefaultDistributorNotSet(distributeType);
    }
  }

  function _assertDistributorRegisered(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    if (!$.distributorRegistry[distributor]) revert IEOLRewardConfigurator__RewardDistributorNotRegistered();
  }

  function _assertNotDefaultDistributor(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    DistributeType distributeType = distributor.distributeType();
    if (address($.defaultDistributor[distributeType]) == address(distributor)) {
      revert EOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed();
    }
  }
}
