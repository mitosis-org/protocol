// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { CrossChainRegistryStorageV1 } from './CrossChainRegistryStorageV1.sol';
import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { MsgType } from './messages/Message.sol';
import { Arrays } from '../../lib/Arrays.sol';

contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  bytes32 public constant REGISTERER_ROLE = keccak256('REGISTERER_ROLE');

  event ChainSet(uint256 indexed chainId, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chainId, address indexed vault, address indexed underlyingAsset);

  error CrossChainRegistry__NotRegistered();
  error CrossChainRegistry__AlreadyRegistered();

  modifier onlyRegisterer() {
    _checkRole(REGISTERER_ROLE);
    _;
  }

  modifier onlyRegisteredChain(uint256 chainId) {
    uint256[] memory chainIds = _getStorageV1().chainIds;
    if (!Arrays.exists(chainIds, chainId)) {
      revert CrossChainRegistry__NotRegistered();
    }
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

  function getVault(uint256 chainId, address asset) external view returns (address) {
    return _getStorageV1().chains[chainId].vaults[asset];
  }

  function getVaultUnderlyingAsset(uint256 chainId, address vault) external view returns (address) {
    return _getStorageV1().chains[chainId].underlyingAssets[vault];
  }

  function getChainIdByHyperlaneDomain(uint32 hplDomain) external view returns (uint256) {
    return _getStorageV1().hyperlanes[hplDomain].chainId;
  }

  // Mutative functions
  //
  // TODO: update methods

  function setChain(uint256 chainId, string calldata name, uint32 hplDomain) external onlyRegisterer {
    StorageV1 storage $ = _getStorageV1();

    bool alreadySet = Arrays.exists($.chainIds, chainId) || Arrays.exists($.hplDomains, hplDomain);
    if (alreadySet) {
      revert CrossChainRegistry__AlreadyRegistered();
    }

    $.chainIds.push(chainId);
    $.hplDomains.push(hplDomain);
    $.chains[chainId].name = name;
    $.chains[chainId].hplDomain = hplDomain;
    $.hyperlanes[hplDomain].chainId = chainId;

    emit ChainSet(chainId, hplDomain, name);
  }

  function setVault(uint256 chainId, address vault, address underlyingAsset)
    external
    onlyRegisterer
    onlyRegisteredChain(chainId)
  {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId];
    if (Arrays.exists(chainInfo.vaultAddresses, vault)) {
      revert CrossChainRegistry__AlreadyRegistered();
    }

    chainInfo.vaultAddresses.push(vault);
    chainInfo.vaults[underlyingAsset] = vault;
    chainInfo.underlyingAssets[vault] = underlyingAsset;

    emit VaultSet(chainId, vault, underlyingAsset);
  }
}
