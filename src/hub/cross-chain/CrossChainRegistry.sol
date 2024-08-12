// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { CrossChainRegistryStorageV1 } from './CrossChainRegistryStorageV1.sol';
import { MsgType } from './messages/Message.sol';

contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  bytes32 public constant REGISTERER_ROLE = keccak256('REGISTERER_ROLE');

  event ChainSet(uint256 indexed chainId, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chainId, address indexed vault);
  event UnderlyingAssetSet(uint256 indexed chainId, address indexed vault, address indexed underlyingAsset);

  error CrossChainRegistry__NotRegistered();
  error CrossChainRegistry__AlreadyRegistered();

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

  function getVault(uint256 chainId) external view returns (address) {
    return _getStorageV1().chains[chainId].vault;
  }

  function getChainIdByHyperlaneDomain(uint32 hplDomain) external view returns (uint256) {
    return _getStorageV1().hyperlanes[hplDomain].chainId;
  }

  function isSupportUnderlyingAsset(uint256 chainId, address underlyingAsset) external view returns (bool) {
    return _getStorageV1().chains[chainId].underlyingAssets[underlyingAsset];
  }

  // Mutative functions
  //
  // TODO: update methods

  function setChain(uint256 chainId, string calldata name, uint32 hplDomain) external onlyRegisterer {
    StorageV1 storage $ = _getStorageV1();

    if (_isRegisteredChain($.chains[chainId]) || _isRegisteredHyperlane($.hyperlanes[hplDomain])) {
      revert CrossChainRegistry__AlreadyRegistered();
    }

    $.chainIds.push(chainId);
    $.hplDomains.push(hplDomain);
    $.chains[chainId].name = name;
    $.chains[chainId].hplDomain = hplDomain;
    $.hyperlanes[hplDomain].chainId = chainId;

    emit ChainSet(chainId, hplDomain, name);
  }

  function setVault(uint256 chainId, address vault) external onlyRegisterer {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId];
    if (!_isRegisteredChain(chainInfo)) {
      revert CrossChainRegistry__NotRegistered();
    }

    if (_isRegisteredVault(chainInfo)) {
      revert CrossChainRegistry__AlreadyRegistered();
    }

    chainInfo.vault = vault;
    emit VaultSet(chainId, vault);
  }

  function setUnderlyingAsset(address underlyingAsset) external {
    StorageV1 storage $ = _getStorageV1();
    for (uint256 i = 0; i < $.chainIds.length; i++) {
      uint256 chainId = $.chainIds[i];
      setUnderlyingAsset(chainId, underlyingAsset);
    }
  }

  function setUnderlyingAsset(uint256 chainId, address underlyingAsset) public {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId];
    if (chainInfo.vault == address(0)) {
      revert CrossChainRegistry__NotRegistered();
    }
    chainInfo.underlyingAssets[underlyingAsset] = true;
    emit UnderlyingAssetSet(chainId, chainInfo.vault, underlyingAsset);
  }

  // Internal functions

  function _isRegisteredChain(ChainInfo storage chainInfo) internal view returns (bool) {
    return bytes(chainInfo.name).length > 0;
  }

  function _isRegisteredVault(ChainInfo storage chainInfo) internal view returns (bool) {
    return chainInfo.vault != address(0);
  }

  function _isRegisteredHyperlane(HyperlaneInfo storage hplInfo) internal view returns (bool) {
    return hplInfo.chainId > 0;
  }
}
