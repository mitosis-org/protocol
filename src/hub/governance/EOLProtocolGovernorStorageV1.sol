// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IEOLProtocolRegistry } from '../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import {
  ProposalType,
  InitiationProposalPayload,
  DeletionProposalPayload,
  VoteOption
} from '../../interfaces/hub/governance/IEOLProtocolGovernor.sol';

struct Proposal {
  address proposer;
  ProposalType proposalType;
  uint48 startsAt;
  uint48 endsAt;
  bytes payload;
  bool executed;
  mapping(address account => VoteOption) votes;
}

contract EOLProtocolGovernorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IEOLProtocolRegistry protocolRegistry;
    address eolVault;
    uint32 twabPeriod;
    mapping(uint256 proposalId => Proposal) proposals;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLProtocolGovernorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
