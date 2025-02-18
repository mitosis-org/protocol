// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IRouter } from '@hpl-v5/interfaces/IRouter.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { Conv } from '../../lib/Conv.sol';
import { CrossChainRegistryStorageV1 } from './CrossChainRegistryStorageV1.sol';

/// Note: This contract stores data that needs to be shared across chains.
contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  UUPSUpgradeable,
  CrossChainRegistryStorageV1
{
  using Conv for *;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

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

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function setChain(uint256 chainId_, string calldata name, uint32 hplDomain, address entrypoint_) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    require(
      !_isRegisteredChain($.chains[chainId_]) && !_isRegisteredHyperlane($.hyperlanes[hplDomain]),
      ICrossChainRegistry.ICrossChainRegistry__AlreadyRegistered()
    );

    $.chainIds.push(chainId_);
    $.hplDomains.push(hplDomain);
    $.chains[chainId_].name = name;
    $.chains[chainId_].hplDomain = hplDomain;
    $.chains[chainId_].entrypoint = entrypoint_;
    $.hyperlanes[hplDomain].chainId = chainId_;

    emit ChainSet(chainId_, hplDomain, entrypoint_, name);
  }

  function setVault(uint256 chainId_, address vault_) external onlyOwner {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId_];

    require(_isRegisteredChain(chainInfo), ICrossChainRegistry.ICrossChainRegistry__NotRegistered());
    require(!_isRegisteredVault(chainInfo), ICrossChainRegistry.ICrossChainRegistry__AlreadyRegistered());

    chainInfo.vault = vault_;
    emit VaultSet(chainId_, vault_);
  }

  function enrollEntrypoint(address hplRouter) external onlyOwner {
    uint256[] memory allChainIds = _getStorageV1().chainIds;
    for (uint256 i = 0; i < allChainIds.length; i++) {
      enrollEntrypoint(hplRouter, allChainIds[i]);
    }
  }

  function enrollEntrypoint(address hplRouter, uint256 chainId_) public onlyOwner {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId_];
    if (_isEnrollableChain(chainInfo)) {
      chainInfo.entrypointEnrolled = true;
      IRouter(hplRouter).enrollRemoteRouter(chainInfo.hplDomain, chainInfo.entrypoint.toBytes32());
    }
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

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
