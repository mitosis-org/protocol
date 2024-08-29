// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

struct ProtocolInfo {
  uint256 protocolId;
  address eolAsset;
  uint256 chainId;
  string name;
  string metadata;
  uint48 registeredAt;
}

contract EOLProtocolRegistryStorageV1 {
  using ERC7201Utils for string;

  struct IndexData {
    EnumerableSet.UintSet protocolIds;
  }

  struct StorageV1 {
    mapping(uint256 protocolId => ProtocolInfo) protocols;
    mapping(address eolAsset => mapping(uint256 chainId => IndexData)) indexes;
    mapping(address eolAsset => mapping(address account => bool)) isAuthorized;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLProtocolRegistryStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
