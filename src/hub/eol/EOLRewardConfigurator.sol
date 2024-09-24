// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { DistributionType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { DistributionType, IRewardDistributor } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { EOLRewardConfiguratorStorageV1 } from './EOLRewardConfiguratorStorageV1.sol';

contract EOLRewardConfigurator is IEOLRewardConfigurator, Ownable2StepUpgradeable, EOLRewardConfiguratorStorageV1 {
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 public constant REWARD_RATIO_PRECISION = 10e4;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  function getDistributionType(address eolVault, address asset) external view returns (DistributionType) {
    return _getStorageV1().distributionTypes[eolVault][asset];
  }

  function getDefaultDistributor(DistributionType distributionType) external view returns (IRewardDistributor) {
    return _getStorageV1().defaultDistributor[distributionType];
  }

  function rewardRatioPrecision() external pure returns (uint256) {
    return REWARD_RATIO_PRECISION;
  }

  function getEOLAssetHolderRewardRatio() external pure returns (uint256) {
    return REWARD_RATIO_PRECISION; // 100%
  }

  function isDistributorRegistered(IRewardDistributor distributor) external view returns (bool) {
    return _isDistributorRegistered(_getStorageV1(), distributor);
  }

  // Mutative functions

  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType)
    external
    onlyOwner
  {
    StorageV1 storage $ = _getStorageV1();

    _assertDefaultDistributorSet($, distributionType);

    $.distributionTypes[eolVault][asset] = distributionType;
    emit RewardDistributionTypeSet(eolVault, asset, distributionType);
  }

  function setDefaultDistributor(IRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegisered($, distributor);

    DistributionType distributionType = distributor.distributionType();

    $.defaultDistributor[distributionType] = distributor;
    emit DefaultDistributorSet(distributionType, distributor);
  }

  function registerDistributor(IRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertValidRewardDistributor(distributor);
    _assertDistributorNotRegisered($, distributor);

    $.distributorLists[distributor.distributionType()].add(address(distributor));
    emit RewardDistributorRegistered(distributor);
  }

  function unregisterDistributor(IRewardDistributor distributor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegisered($, distributor);
    _assertNotDefaultDistributor($, distributor);

    $.distributorLists[distributor.distributionType()].remove(address(distributor));

    emit RewardDistributorUnregistered(distributor);
  }

  function _isDistributorRegistered(StorageV1 storage $, IRewardDistributor distributor) internal view returns (bool) {
    return $.distributorLists[distributor.distributionType()].contains(address(distributor));
  }

  function _assertDefaultDistributorSet(StorageV1 storage $, DistributionType distributionType) internal view {
    require(
      address($.defaultDistributor[distributionType]) != address(0),
      EOLRewardConfigurator__DefaultDistributorNotSet(distributionType)
    );
  }

  function _assertDistributorRegisered(StorageV1 storage $, IRewardDistributor distributor) internal view {
    require(_isDistributorRegistered($, distributor), IEOLRewardConfigurator__RewardDistributorNotRegistered());
  }

  function _assertDistributorNotRegisered(StorageV1 storage $, IRewardDistributor distributor) internal view {
    require(!_isDistributorRegistered($, distributor), IEOLRewardConfigurator__RewardDistributorAlreadyRegistered());
  }

  function _assertNotDefaultDistributor(StorageV1 storage $, IRewardDistributor distributor) internal view {
    DistributionType distributionType = distributor.distributionType();
    require(
      address(distributor) != address($.defaultDistributor[distributionType]),
      EOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed()
    );
  }

  function _assertValidRewardDistributor(IRewardDistributor distributor) internal view {
    require(
      address(this) == address(distributor.rewardConfigurator()), EOLRewardConfigurator__InvalidRewardConfigurator()
    );
  }
}
