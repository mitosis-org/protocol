// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { DistributionType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { EOLRewardConfiguratorStorageV1 } from './storage/EOLRewardConfiguratorStorageV1.sol';

contract EOLRewardConfigurator is IEOLRewardConfigurator, Ownable2StepUpgradeable, EOLRewardConfiguratorStorageV1 {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // Mutative functions

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType)
    external
    onlyOwner
  {
    _setRewardDistributionType(eolVault, asset, distributionType);
  }

  function setDefaultDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    _setDefaultDistributor(distributor);
  }

  function registerDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorNotRegisered($, distributor);

    $.distributorLists[distributor.distributionType()].add(address(distributor));
    emit RewardDistributorRegistered(distributor);
  }

  function unregisterDistributor(IEOLRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegisered($, distributor);
    _assertNotDefaultDistributor($, distributor);

    $.distributorLists[distributor.distributionType()].remove(address(distributor));

    emit RewardDistributorUnregistered(distributor);
  }

  function _assertDistributorNotRegisered(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    require(
      !_isDistributorRegistered($, distributor), IEOLRewardConfiguratorStorageV1__RewardDistributorNotRegistered()
    );
  }

  function _assertNotDefaultDistributor(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    DistributionType _distributionType = distributor.distributionType();
    require(
      address(distributor) != address($.defaultDistributor[_distributionType]),
      IEOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed()
    );
  }
}
