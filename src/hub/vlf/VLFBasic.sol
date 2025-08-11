// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';

import { VLF } from './VLF.sol';

/**
 * @title VLFBasic
 * @notice Basic implementation of a VLF that simply inherits the VLF contract
 */
contract VLFBasic is VLF {
  constructor() {
    _disableInitializers();
  }

  function initialize(address assetManager_, IERC20Metadata asset_, string memory name, string memory symbol)
    external
    initializer
  {
    __VLF_init(assetManager_, asset_, name, symbol);
  }
}
