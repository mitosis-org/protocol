// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { TwabCheckpoints } from '../lib/TwabCheckpoints.sol';

contract TwabSnapshotsStorageV1 {
  using ERC7201Utils for string;

  struct TwabSnapshotStorageV1 {
    mapping(address account => TwabCheckpoints.Trace) accountCheckpoints;
    TwabCheckpoints.Trace totalCheckpoints;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TwabSnapshotsStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getTwabSnapshotStorageV1() internal view returns (TwabSnapshotStorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
