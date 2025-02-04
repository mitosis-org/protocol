// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20TWABSnapshots } from '../../interfaces/twab/IERC20TWABSnapshots.sol';
import { MatrixVault } from './MatrixVault.sol';

/**
 * @title MatrixVaultBasic
 * @notice Basic implementation of an MatrixVault by simply inherits the MatrixVault contract
 */
contract MatrixVaultBasic is MatrixVault {
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
    __MatrixVault_init(delegationRegistry_, assetManager_, asset_, name, symbol);
  }
}
