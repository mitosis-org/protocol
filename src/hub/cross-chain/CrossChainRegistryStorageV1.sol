// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
  ICrossChainRegistry, ICrossChainRegistryStorageV1
} from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

abstract contract CrossChainRegistryStorageV1 is ICrossChainRegistryStorageV1 {
  using ERC7201Utils for string;

  event ChainSet(uint256 indexed chainId, uint32 indexed hplDomain, address indexed entrypoint, string name);
  event VaultSet(uint256 indexed chainId, address indexed vault);

  struct ChainInfo {
    string name;
    // Branch info
    uint32 hplDomain;
    address vault;
    address entrypoint;
    bool entrypointEnrolled;
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

  string private constant _NAMESPACE = 'mitosis.storage.CrossChainRegistryStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // View functions

  function chainIds() external view returns (uint256[] memory) {
    return _getStorageV1().chainIds;
  }

  function chainName(uint256 chainId_) external view returns (string memory) {
    return _getStorageV1().chains[chainId_].name;
  }

  function hyperlaneDomain(uint256 chainId_) external view returns (uint32) {
    return _getStorageV1().chains[chainId_].hplDomain;
  }

  function entrypoint(uint256 chainId_) external view returns (address) {
    return _getStorageV1().chains[chainId_].entrypoint;
  }

  function vault(uint256 chainId_) external view returns (address) {
    return _getStorageV1().chains[chainId_].vault;
  }

  function entrypointEnrolled(uint256 chainId_) external view returns (bool) {
    return _isEntrypointEnrolled(_getStorageV1().chains[chainId_]);
  }

  function chainId(uint32 hplDomain) external view returns (uint256) {
    return _getStorageV1().hyperlanes[hplDomain].chainId;
  }

  function isRegisteredChain(uint256 chainId_) external view returns (bool) {
    return _isRegisteredChain(_getStorageV1().chains[chainId_]);
  }

  // Mutative functions
  //
  // TODO: update methods

  function _setChain(uint256 chainId_, string calldata name, uint32 hplDomain, address entrypoint_) internal {
    StorageV1 storage $ = _getStorageV1();

    require(
      !_isRegisteredChain($.chains[chainId_]) && !_isRegisteredHyperlane($.hyperlanes[hplDomain]),
      ICrossChainRegistryStorageV1__AlreadyRegistered()
    );

    $.chainIds.push(chainId_);
    $.hplDomains.push(hplDomain);
    $.chains[chainId_].name = name;
    $.chains[chainId_].hplDomain = hplDomain;
    $.chains[chainId_].entrypoint = entrypoint_;
    $.hyperlanes[hplDomain].chainId = chainId_;

    emit ChainSet(chainId_, hplDomain, entrypoint_, name);
  }

  function _setVault(uint256 chainId_, address vault_) internal {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId_];

    require(_isRegisteredChain(chainInfo), ICrossChainRegistryStorageV1__NotRegistered());
    require(!_isRegisteredVault(chainInfo), ICrossChainRegistryStorageV1__AlreadyRegistered());

    chainInfo.vault = vault_;
    emit VaultSet(chainId_, vault_);
  }

  // Internal functions

  function _isRegisteredChain(ChainInfo storage chainInfo) internal view returns (bool) {
    return bytes(chainInfo.name).length > 0;
  }

  function _isRegisteredVault(ChainInfo storage chainInfo) internal view returns (bool) {
    return chainInfo.vault != address(0);
  }

  function _isEntrypointEnrolled(ChainInfo storage chainInfo) internal view returns (bool) {
    return chainInfo.entrypointEnrolled;
  }

  function _isEnrollableChain(ChainInfo storage chainInfo) internal view returns (bool) {
    return _isRegisteredChain(chainInfo) && !_isEntrypointEnrolled(chainInfo);
  }

  function _isRegisteredHyperlane(HyperlaneInfo storage hplInfo) internal view returns (bool) {
    return hplInfo.chainId > 0;
  }
}
