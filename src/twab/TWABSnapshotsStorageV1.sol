// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { ITWABSnapshots } from '../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';

abstract contract TWABSnapshotsStorageV1 {
  using SafeCast for uint256;
  using ERC7201Utils for string;
  using Checkpoints for Checkpoints.Trace208;
  using TWABCheckpoints for TWABCheckpoints.Trace;

  struct TWABSnapshotsStorageV1_ {
    IDelegationRegistry delegationRegistry;
    TWABCheckpoints.Trace totalCheckpoints;
    mapping(address account => Checkpoints.Trace208) balanceCheckpoints;
    mapping(address account => address delegate) delegates;
    mapping(address account => TWABCheckpoints.Trace) delegateCheckpoints;
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

  function _totalSupplySnapshot(TWABSnapshotsStorageV1_ storage $, uint256 timestamp)
    internal
    view
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    require(timestamp <= currentTimestamp, ITWABSnapshots.ERC5805FutureLookup(timestamp, currentTimestamp));
    return $.totalCheckpoints.upperLookupRecent(timestamp.toUint48());
  }

  function _balanceSnapshot(TWABSnapshotsStorageV1_ storage $, address account, uint256 timestamp)
    internal
    view
    returns (uint208)
  {
    uint48 currentTimestamp = clock();
    require(timestamp <= currentTimestamp, ITWABSnapshots.ERC5805FutureLookup(timestamp, currentTimestamp));
    return $.balanceCheckpoints[account].upperLookupRecent(timestamp.toUint48());
  }

  function _delegationSnapshot(TWABSnapshotsStorageV1_ storage $, address account, uint256 timestamp)
    internal
    view
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    require(timestamp <= currentTimestamp, ITWABSnapshots.ERC5805FutureLookup(timestamp, currentTimestamp));
    return $.delegateCheckpoints[account].upperLookupRecent(timestamp.toUint48());
  }

  function clock() public view virtual returns (uint48);
}
