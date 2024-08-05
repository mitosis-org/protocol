// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

abstract contract StdStrategyStorageV1 {
  struct StdStorageV1 {
    bytes32 placeholder; // TODO: remove this line when adding storage variables
  }

  bytes32 private immutable StorageV1Location;

  function strategyName() public pure virtual returns (string memory);

  constructor() {
    bytes memory namespace = bytes(string.concat('mitosis.storage.strategy.', strategyName(), '.std.v1'));
    StorageV1Location = keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff));
  }

  function _getStdStorageV1() internal view returns (StdStorageV1 storage $) {
    bytes32 slot = StorageV1Location;

    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
