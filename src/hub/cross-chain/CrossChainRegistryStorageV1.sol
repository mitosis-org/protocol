// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

contract CrossChainRegistryStorageV1 {
  using ERC7201Utils for string;
  struct ChainInfo {
    string name;
    uint32 hplDomain;
    address vault;
    mapping(address underlyingAsset => bool) underlyingAssets;
  }

  struct HyperlaneInfo {
    uint256 chainId;
  }

  struct StorageV1 {
    uint256[] chainIds;
    uint32[] hplDomains;
    mapping(uint256 chainId => ChainInfo) chains;
    mapping(uint32 hplDomain => HyperlaneInfo) hyperlanes;
  }

  string constant _NAMESPACE = 'mitosis.storage.CrossChainRegistryStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 storageLocation = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := storageLocation
    }
  }
}
