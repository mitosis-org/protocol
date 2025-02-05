// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Snapshots } from '../../interfaces/twab/IERC20Snapshots.sol';
import { MatrixVault } from './MatrixVault.sol';

/**
 * @title MatrixVaultBasic
 * @notice Basic implementation of an MatrixVault by simply inherits the MatrixVault contract
 */
contract MatrixVaultBasic is MatrixVault {
  constructor() {
    _disableInitializers();
  }

  function initialize(address assetManager_, IERC20Snapshots asset_, string memory name, string memory symbol)
    external
    initializer
  {
    __MatrixVault_init(assetManager_, asset_, name, symbol);
  }
}
