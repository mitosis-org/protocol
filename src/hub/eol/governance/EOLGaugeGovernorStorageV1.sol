// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IEOLProtocolRegistry } from '../../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { IEOLVault } from '../../../interfaces/hub/eol/vault/IEOLVault.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract EOLGaugeGovernorStorageV1 {
  using ERC7201Utils for string;

  struct Epoch {
    uint256 id;
    uint48 startsAt;
    uint48 endsAt;
    mapping(uint256 chainId => EpochVoteInfo) voteInfoByChainId;
  }

  struct EpochVoteInfo {
    uint256[] protocolIds;
    mapping(address account => uint32[] gauges) gaugesByAccount;
  }

  struct TotalVoteInfo {
    EnumerableSet.AddressSet voters;
    mapping(address account => uint256[] votedEpochIds) votedEpochIdsByAccount;
  }

  struct Governance {
    IEOLVault eolVault;
    uint32 epochPeriod;
    uint256 lastEpochId;
    mapping(uint256 epochId => Epoch) epochs;
    mapping(uint256 chainId => TotalVoteInfo) totalVoteInfoByChainId;
  }

  struct StorageV1 {
    IEOLProtocolRegistry protocolRegistry;
    mapping(address eolVault => Governance) governances;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLGaugeGovernorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
