// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DistributeType } from '../../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { IEOLRewardDistributor } from '../../../interfaces/hub/eol/IEOLRewardDistributor.sol';

contract EOLRewardConfiguratorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    mapping(address eolVault => mapping(address asset => DistributeType distributeType)) distributeTypes;
    mapping(DistributeType distributeType => IEOLRewardDistributor distributor) defaultDistributor;
    mapping(IEOLRewardDistributor distributor => bool registered) distributorRegistry;
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
