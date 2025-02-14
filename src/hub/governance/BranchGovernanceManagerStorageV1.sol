// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IBranchGovernanceManagerEntrypoint } from
  '../../interfaces/hub/governance/IBranchGovernanceManagerEntrypoint.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { BranchGovernanceManagerEntrypoint } from './BranchGovernanceManagerEntrypoint.sol';

contract BranchGovernanceManagerStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IBranchGovernanceManagerEntrypoint entrypoint;
    mapping(address account => bool isExecutor) executors;
    address mitoGovernance;
  }

  string private constant _NAMESPACE = 'mitosis.storage.BranchGovernanceManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
