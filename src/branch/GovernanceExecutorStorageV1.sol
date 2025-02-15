// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IGovernanceExecutorEntrypoint } from '../interfaces/branch/IGovernanceExecutorEntrypoint.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

abstract contract GovernanceExecutorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IGovernanceExecutorEntrypoint entrypoint;
    mapping(address account => bool isManager) managers;
  }

  string private constant _NAMESPACE = 'mitosis.storage.GovernanceExecutorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
