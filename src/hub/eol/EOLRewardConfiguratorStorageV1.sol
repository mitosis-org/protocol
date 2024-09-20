// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IRewardDistributor, DistributionType } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

contract EOLRewardConfiguratorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    // TODO(ray): Reward ratio
    //
    mapping(address eolVault => mapping(address asset => DistributionType distributionType)) distributionTypes;
    mapping(DistributionType distributionType => EnumerableSet.AddressSet distributors) distributorLists;
    // note: We strictly manage the DefaultDistributor. DistributionTypes without a set
    // DefaultDistributor cannot be configured as the distribution method for assets.
    // And once initialized, the DefaultDistributor cannot be set to a zero address.
    mapping(DistributionType distributionType => IRewardDistributor distributor) defaultDistributor;
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
}
