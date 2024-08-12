// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC7201Utils } from '@src/lib/ERC7201Utils.sol';

abstract contract StdStrategyStorageV1 {
  using ERC7201Utils for string;

  struct StdStorageV1 {
    bytes32 placeholder; // NOTE: remove this line when adding storage variables
  }

  bytes32 public immutable StorageV1Location;

  function strategyName() public pure virtual returns (string memory);

  constructor() {
    string memory namespace = string.concat('mitosis.storage.strategy.', strategyName(), '.std.v1');
    StorageV1Location = namespace.storageSlot();
  }

  function _getStdStorageV1() internal view returns (StdStorageV1 storage $) {
    bytes32 slot = StorageV1Location;

    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
