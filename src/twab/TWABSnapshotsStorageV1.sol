// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';

contract TWABSnapshotsStorageV1 {
  using ERC7201Utils for string;

  struct TWABSnapshotsStorageV1_ {
    IDelegationRegistry delegationRegistry;
    mapping(address account => address delegate) delegates;
    mapping(address account => TWABCheckpoints.Trace) delegateCheckpoints;
    mapping(address account => TWABCheckpoints.Trace) accountCheckpoints;
    TWABCheckpoints.Trace totalCheckpoints;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TWABSnapshotsStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getTWABSnapshotsStorageV1() internal view returns (TWABSnapshotsStorageV1_ storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
