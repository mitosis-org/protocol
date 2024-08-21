// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IRouter } from '@hpl-v5/interfaces/IRouter.sol';
import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { CrossChainRegistryStorageV1 } from './CrossChainRegistryStorageV1.sol';
import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { Conv } from '../../lib/Conv.sol';

/// Note: This contract stores data that needs to be shared across chains.
contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  using Conv for *;

  bytes32 public constant REGISTERER_ROLE = keccak256('REGISTERER_ROLE');

  event ChainSet(uint256 indexed chainId, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chainId, address indexed vault);

  modifier onlyRegisterer() {
    _checkRole(REGISTERER_ROLE);
    _;
  }

  //===========

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    __AccessControl_init();
    _transferOwnership(owner);
    _grantRole(DEFAULT_ADMIN_ROLE, owner);
  }

  // View functions

  function getChainIds() external view returns (uint256[] memory) {
    return _getStorageV1().chainIds;
  }

  function getChainName(uint256 chainId) external view returns (string memory) {
    return _getStorageV1().chains[chainId].name;
  }

  function getHyperlaneDomain(uint256 chainId) external view returns (uint32) {
    return _getStorageV1().chains[chainId].hplDomain;
  }

  function getEntrypoint(uint256 chainId) external view returns (address) {
    return _getStorageV1().chains[chainId].entrypoint;
  }

  function getVault(uint256 chainId) external view returns (address) {
    return _getStorageV1().chains[chainId].vault;
  }

  function entrypointEnrolled(uint256 chainId) external view returns (bool) {
    return _isEntrypointEnrolled(_getStorageV1().chains[chainId]);
  }

  function getChainIdByHyperlaneDomain(uint32 hplDomain) external view returns (uint256) {
    return _getStorageV1().hyperlanes[hplDomain].chainId;
  }

  function isRegisteredChain(uint256 chainId) external view returns (bool) {
    return _isRegisteredChain(_getStorageV1().chains[chainId]);
  }

  // Mutative functions
  //
  // TODO: update methods

  function setChain(uint256 chainId, string calldata name, uint32 hplDomain, address entrypoint)
    external
    onlyRegisterer
  {
    StorageV1 storage $ = _getStorageV1();

    if (_isRegisteredChain($.chains[chainId]) || _isRegisteredHyperlane($.hyperlanes[hplDomain])) {
      revert ICrossChainRegistry.ICrossChainRegistry__AlreadyRegistered();
    }

    $.chainIds.push(chainId);
    $.hplDomains.push(hplDomain);
    $.chains[chainId].name = name;
    $.chains[chainId].hplDomain = hplDomain;
    $.chains[chainId].entrypoint = entrypoint;
    $.hyperlanes[hplDomain].chainId = chainId;

    emit ChainSet(chainId, hplDomain, name);
  }

  function setVault(uint256 chainId, address vault) external onlyRegisterer {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId];
    if (!_isRegisteredChain(chainInfo)) {
      revert ICrossChainRegistry.ICrossChainRegistry__NotRegistered();
    }

    if (_isRegisteredVault(chainInfo)) {
      revert ICrossChainRegistry.ICrossChainRegistry__AlreadyRegistered();
    }

    chainInfo.vault = vault;
    emit VaultSet(chainId, vault);
  }

  function enrollEntrypoint(address hplRouter) external onlyRegisterer {
    uint256[] memory chainIds = _getStorageV1().chainIds;
    // TODO(ray): IRouter.enrollRemoteRouters
    for (uint256 i = 0; i < chainIds.length; i++) {
      enrollEntrypoint(hplRouter, chainIds[i]);
    }
  }

  function enrollEntrypoint(address hplRouter, uint256 chainId) public onlyRegisterer {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId];
    if (_isEnrollableChain(chainInfo)) {
      chainInfo.entrypointEnrolled = true;
      IRouter(hplRouter).enrollRemoteRouter(chainInfo.hplDomain, chainInfo.entrypoint);
    }
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
