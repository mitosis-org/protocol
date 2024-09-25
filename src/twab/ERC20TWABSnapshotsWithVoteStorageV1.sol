// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IVoteManager } from '../interfaces/hub/core/IVoteManager.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';

contract ERC20TWABSnapshotsWithVoteStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IVoteManager voteManager;
    mapping(address account => address delegate) delegates;
    mapping(address account => TWABCheckpoints.Trace) delegateCheckpoints;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TWABVoteSnapshotsStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
