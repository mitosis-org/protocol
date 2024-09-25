// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

abstract contract VoteManagerStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    mapping(address account => address delegationManager) delegationManagers;
    mapping(address account => address defaultDelegatee) defaultDelegatees;
  }

  string private constant _NAMESPACE = 'mitosis.storage.VoteManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getVoteManagerStorageV1() internal view returns (StorageV1 storage store) {
    bytes32 slot = _slot;
    assembly {
      store.slot := slot
    }
  }
}
