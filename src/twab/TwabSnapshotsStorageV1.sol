// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TwabCheckpoints } from '../lib/TwabCheckpoints.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

contract TwabSnapshotsStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    mapping(address account => TwabCheckpoints.Trace) accountCheckpoints;
    TwabCheckpoints.Trace totalCheckpoints;
  }

  string constant _NAMESPACE = 'mitosis.storage.TwabSnapshotsStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 storageLocation = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := storageLocation
    }
  }
}
