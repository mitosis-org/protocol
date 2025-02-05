// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';

import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

abstract contract SnapshotsStorageV1 {
  using SafeCast for uint256;
  using ERC7201Utils for string;
  using Checkpoints for Checkpoints.Trace208;

  /**
   * @dev Error thrown when the ERC6372 clock is inconsistent.
   */
  error ERC6372InconsistentClock();

  /**
   * @dev Error thrown when the timestamp is greater than the current timestamp.
   */
  error ERC5805FutureLookup(uint256 timestamp, uint256 currentTimestamp);

  struct SnapshotsStorageV1_ {
    Checkpoints.Trace208 totalCheckpoints;
    mapping(address account => Checkpoints.Trace208) balanceCheckpoints;
  }

  string private constant _NAMESPACE = 'mitosis.storage.SnapshotsStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getSnapshotsStorageV1() internal view returns (SnapshotsStorageV1_ storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  function _totalSupplySnapshot(SnapshotsStorageV1_ storage $, uint256 timestamp) internal view returns (uint208) {
    uint48 currentTimestamp = clock();
    require(timestamp <= currentTimestamp, ERC5805FutureLookup(timestamp, currentTimestamp));
    return $.totalCheckpoints.upperLookupRecent(timestamp.toUint48());
  }

  function _balanceSnapshot(SnapshotsStorageV1_ storage $, address account, uint256 timestamp)
    internal
    view
    returns (uint208)
  {
    uint48 currentTimestamp = clock();
    require(timestamp <= currentTimestamp, ERC5805FutureLookup(timestamp, currentTimestamp));
    return $.balanceCheckpoints[account].upperLookupRecent(timestamp.toUint48());
  }

  function clock() public view virtual returns (uint48);
}
