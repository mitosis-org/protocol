// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';

import { MatrixVault } from './MatrixVault.sol';

/**
 * @title MatrixVaultBasic
 * @notice Basic implementation of an MatrixVault by simply inherits the MatrixVault contract
 */
contract MatrixVaultBasic is MatrixVault {
  constructor() {
    _disableInitializers();
  }

  function initialize(address assetManager_, IERC20Metadata asset_, string memory name, string memory symbol)
    external
    initializer
  {
    __MatrixVault_init(assetManager_, asset_, name, symbol);
  }
}
