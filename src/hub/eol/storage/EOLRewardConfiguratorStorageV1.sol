// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { DistributionType } from '../../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import {
  IEOLRewardConfigurator,
  IEOLRewardConfiguratorStorageV1
} from '../../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract EOLRewardConfiguratorStorageV1 is IEOLRewardConfiguratorStorageV1 {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ERC7201Utils for string;

  struct StorageV1 {
    // TODO(ray): Reward ratio
    //
    mapping(address eolVault => mapping(address asset => DistributionType distributionType)) distributionTypes;
    mapping(DistributionType distributionType => EnumerableSet.AddressSet distributors) distributorLists;
    // note: We strictly manage the DefaultDistributor. DistributionTypes without a set
    // DefaultDistributor cannot be configured as the distribution method for assets.
    // And once initialized, the DefaultDistributor cannot be set to a zero address.
    mapping(DistributionType distributionType => IEOLRewardDistributor distributor) defaultDistributor;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLRewardConfiguratorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function distributionType(address eolVault, address asset) external view returns (DistributionType) {
    return _getStorageV1().distributionTypes[eolVault][asset];
  }

  function defaultDistributor(DistributionType distributionType_) external view returns (IEOLRewardDistributor) {
    return _getStorageV1().defaultDistributor[distributionType_];
  }

  function rewardRatioPrecision() public pure returns (uint256) {
    return 10e4;
  }

  function eolAssetHolderRewardRatio() external pure returns (uint256) {
    return rewardRatioPrecision(); // 100%
  }

  function isDistributorRegistered(IEOLRewardDistributor distributor) external view returns (bool) {
    return _isDistributorRegistered(_getStorageV1(), distributor);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _setRewardDistributionType(address eolVault, address asset, DistributionType distributionType_) internal {
    StorageV1 storage $ = _getStorageV1();

    _assertDefaultDistributorSet($, distributionType_);

    $.distributionTypes[eolVault][asset] = distributionType_;
    emit RewardDistributionTypeSet(eolVault, asset, distributionType_);
  }

  function _setDefaultDistributor(IEOLRewardDistributor distributor) internal {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegisered($, distributor);

    DistributionType distributionType_ = distributor.distributionType();

    $.defaultDistributor[distributionType_] = distributor;
    emit DefaultDistributorSet(distributionType_, distributor);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _isDistributorRegistered(StorageV1 storage $, IEOLRewardDistributor distributor)
    internal
    view
    returns (bool)
  {
    return $.distributorLists[distributor.distributionType()].contains(address(distributor));
  }

  function _assertDefaultDistributorSet(StorageV1 storage $, DistributionType distributionType_) internal view {
    require(
      address($.defaultDistributor[distributionType_]) != address(0),
      IEOLRewardConfiguratorStorageV1__DefaultDistributorNotSet(distributionType_)
    );
  }

  function _assertDistributorRegisered(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    require(_isDistributorRegistered($, distributor), IEOLRewardConfiguratorStorageV1__RewardDistributorNotRegistered());
  }
}
