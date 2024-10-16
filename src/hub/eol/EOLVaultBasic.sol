// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20TWABSnapshots } from '../../interfaces/twab/IERC20TWABSnapshots.sol';
import { EOLVault } from './EOLVault.sol';

/**
 * @title EOLVaultBasic
 * @notice Basic implementation of an EOLVault by simply inherits the EOLVault contract
 */
contract EOLVaultBasic is EOLVault {
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address delegationRegistry_,
    address assetManager_,
    IERC20TWABSnapshots asset_,
    string memory name,
    string memory symbol
  ) external initializer {
    __EOLVault_init(delegationRegistry_, assetManager_, asset_, name, symbol);
  }
}
