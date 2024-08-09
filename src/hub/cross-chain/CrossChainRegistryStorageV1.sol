// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract CrossChainRegistryStorageV1 {
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

  // keccak256(abi.encode(uint256(keccak256("mitosis.storage.CrossChainRegistryStorage.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0x6acd94fd2c3942266402dfa199ad817aa94ac6cd3de826b0b51cbc305ff61c00;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}
