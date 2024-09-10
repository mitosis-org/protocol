// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRouter } from '@hpl-v5/interfaces/IRouter.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { Conv } from '../../lib/Conv.sol';
import { CrossChainRegistryStorageV1 } from './CrossChainRegistryStorageV1.sol';

/// Note: This contract stores data that needs to be shared across chains.
contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  using Conv for *;

  bytes32 public constant REGISTERER_ROLE = keccak256('REGISTERER_ROLE');

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

  // Mutative functions
  //
  // TODO: update methods

  function setChain(uint256 chainId_, string calldata name, uint32 hplDomain, address entrypoint_)
    external
    onlyRegisterer
  {
    _setChain(chainId_, name, hplDomain, entrypoint_);
  }

  function setVault(uint256 chainId_, address vault_) external onlyRegisterer {
    _setVault(chainId_, vault_);
  }

  function enrollEntrypoint(address hplRouter) external onlyRegisterer {
    uint256[] memory allChainIds = _getStorageV1().chainIds;
    // TODO(ray): IRouter.enrollRemoteRouters
    for (uint256 i = 0; i < allChainIds.length; i++) {
      enrollEntrypoint(hplRouter, allChainIds[i]);
    }
  }

  function enrollEntrypoint(address hplRouter, uint256 chainId_) public onlyRegisterer {
    ChainInfo storage chainInfo = _getStorageV1().chains[chainId_];
    if (_isEnrollableChain(chainInfo)) {
      chainInfo.entrypointEnrolled = true;
      IRouter(hplRouter).enrollRemoteRouter(chainInfo.hplDomain, chainInfo.entrypoint.toBytes32());
    }
  }
}
