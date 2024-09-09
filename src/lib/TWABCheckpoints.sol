// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/Checkpoints.sol)
// This file was procedurally generated from scripts/generate/templates/Checkpoints.js.
//
// Modified for the Mitosis development.

pragma solidity ^0.8.26;

import { Math } from '@oz-v5/utils/math/Math.sol';

/**
 * @dev This library defines the `Trace` struct, for checkpointing values as they change at different points in
 * time, and later looking up past values by block.timestamp.
 *
 * To create a history of checkpoints define a variable type `TWABCheckpoints.Trace` in your contract, and store a new
 * checkpoint for the current transaction block using the {push} function.
 */
library TWABCheckpoints {
  /**
   * @dev A value was attempted to be inserted on a past checkpoint.
   */
  error CheckpointUnorderedInsertion();

  struct Trace {
    Checkpoint[] _checkpoints;
  }

  struct Checkpoint {
    uint48 _timestamp;
    uint208 _balance;
    uint256 _accumulatedTWAB; // _accumulatedTWAB stores previous Checkpoint accumlated TWAB value.
  }

  /**
   * @dev Pushes a (`block.timestamp`, `balance`, `twab`) pair into a Trace so that it is stored as the checkpoint.
   *
   * Returns previous balance, new balance and twab, new twab.
   *
   * IMPORTANT: Never accept `block.timestamp` as a user input, since an arbitrary `type(uint48).max` block.timestamp set will disable the
   * library.
   */
  function push(Trace storage self, uint48 timestamp, uint208 balance, uint256 accumulatedTWAB)
    internal
    returns (uint208, uint208, uint256, uint256)
  {
    return _insert(self._checkpoints, timestamp, balance, accumulatedTWAB);
  }

  /**
   * @dev Returns the balance and accumulatedTWAB in the first (oldest) checkpoint with block.timestamp greater or equal than the search block.timestamp, or zero if
   * there is none.
   */
  function lowerLookup(Trace storage self, uint48 timestamp)
    internal
    view
    returns (uint208 balance, uint256 accumulatedTWAB, uint48 position)
  {
    uint256 len = self._checkpoints.length;
    uint256 pos = _lowerBinaryLookup(self._checkpoints, timestamp, 0, len);
    if (pos == len) {
      return (0, 0, 0);
    }
    Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos);
    return (ckpt._balance, ckpt._accumulatedTWAB, ckpt._timestamp);
  }

  /**
   * @dev Returns the balance and accumulatedTWAB in the last (most recent) checkpoint with block.timestamp lower or equal than the search block.timestamp, or zero
   * if there is none.
   */
  function upperLookup(Trace storage self, uint48 timestamp)
    internal
    view
    returns (uint208 balance, uint256 accumulatedTWAB, uint48 position)
  {
    uint256 len = self._checkpoints.length;
    uint256 pos = _upperBinaryLookup(self._checkpoints, timestamp, 0, len);
    if (pos == 0) {
      return (0, 0, 0);
    }
    Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
    return (ckpt._balance, ckpt._accumulatedTWAB, ckpt._timestamp);
  }

  /**
   * @dev Returns the balance and accumulatedTWAB in the last (most recent) checkpoint with block.timestamp lower or equal than the search block.timestamp, or zero
   * if there is none.
   *
   * NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
   * timestamps).
   */
  function upperLookupRecent(Trace storage self, uint48 timestamp)
    internal
    view
    returns (uint208 balance, uint256 accumulatedTWAB, uint48 position)
  {
    uint256 len = self._checkpoints.length;

    uint256 low = 0;
    uint256 high = len;

    if (len > 5) {
      uint256 mid = len - Math.sqrt(len);
      if (timestamp < _unsafeAccess(self._checkpoints, mid)._timestamp) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    uint256 pos = _upperBinaryLookup(self._checkpoints, timestamp, low, high);
    if (pos == 0) {
      return (0, 0, 0);
    }
    Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
    return (ckpt._balance, ckpt._accumulatedTWAB, ckpt._timestamp);
  }

  /**
   * @dev Returns the balance and accumulatedTWAB in the most recent checkpoint, or zero if there are no checkpoints.
   */
  function latest(Trace storage self) internal view returns (uint208 balance, uint256 accumulatedTWAB, uint48 position) {
    uint256 pos = self._checkpoints.length;
    if (pos == 0) {
      return (0, 0, 0);
    }
    Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
    return (ckpt._balance, ckpt._accumulatedTWAB, ckpt._timestamp);
  }

  /**
   * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the block.timestamp and balance and accumulatedTWAB
   * in the most recent checkpoint.
   */
  function latestCheckpoint(Trace storage self)
    internal
    view
    returns (bool exists, uint48 position, uint208 balance, uint256 accumulatedTWAB)
  {
    uint256 pos = self._checkpoints.length;
    if (pos == 0) {
      return (false, 0, 0, 0);
    } else {
      Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
      return (true, ckpt._timestamp, ckpt._balance, ckpt._accumulatedTWAB);
    }
  }

  /**
   * @dev Returns the number of checkpoint.
   */
  function length(Trace storage self) internal view returns (uint256) {
    return self._checkpoints.length;
  }

  /**
   * @dev Returns checkpoint at given position.
   */
  function at(Trace storage self, uint32 pos) internal view returns (Checkpoint memory) {
    return self._checkpoints[pos];
  }

  /**
   * @dev Pushes a (`block.timestamp`, `balance`, `accumulatedTWAB`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
   * or by updating the last one.
   */
  function _insert(Checkpoint[] storage self, uint48 timestamp, uint208 balance, uint256 accumulatedTWAB)
    private
    returns (uint208 lastBalance, uint208 currentBalance, uint256 lastTWAB, uint256 currentTWAB)
  {
    uint256 pos = self.length;

    if (pos > 0) {
      // Copying to memory is important here.
      Checkpoint memory last = _unsafeAccess(self, pos - 1);

      // Checkpoint timestamp must be non-decreasing.
      if (last._timestamp > timestamp) {
        revert CheckpointUnorderedInsertion();
      }

      // Update or push new checkpoint
      if (last._timestamp == timestamp) {
        Checkpoint storage ckpt = _unsafeAccess(self, pos - 1);
        ckpt._balance = balance;
        ckpt._accumulatedTWAB = accumulatedTWAB;
      } else {
        self.push(Checkpoint({ _timestamp: timestamp, _balance: balance, _accumulatedTWAB: accumulatedTWAB }));
      }
      return (last._balance, balance, last._accumulatedTWAB, accumulatedTWAB);
    } else {
      self.push(Checkpoint({ _timestamp: timestamp, _balance: balance, _accumulatedTWAB: accumulatedTWAB }));
      return (0, balance, 0, accumulatedTWAB);
    }
  }

  /**
   * @dev Return the index of the last (most recent) checkpoint with block.timestamp lower or equal than the search block.timestamp, or `high`
   * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
   * `high`.
   *
   * WARNING: `high` should not be greater than the array's length.
   */
  function _upperBinaryLookup(Checkpoint[] storage self, uint48 timestamp, uint256 low, uint256 high)
    private
    view
    returns (uint256)
  {
    while (low < high) {
      uint256 mid = Math.average(low, high);
      if (_unsafeAccess(self, mid)._timestamp > timestamp) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return high;
  }

  /**
   * @dev Return the index of the first (oldest) checkpoint with block.timestamp is greater or equal than the search block.timestamp, or
   * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
   * exclusive `high`.
   *
   * WARNING: `high` should not be greater than the array's length.
   */
  function _lowerBinaryLookup(Checkpoint[] storage self, uint48 timestamp, uint256 low, uint256 high)
    private
    view
    returns (uint256)
  {
    while (low < high) {
      uint256 mid = Math.average(low, high);
      if (_unsafeAccess(self, mid)._timestamp < timestamp) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return high;
  }

  /**
   * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
   */
  function _unsafeAccess(Checkpoint[] storage self, uint256 pos) private pure returns (Checkpoint storage result) {
    assembly {
      mstore(0, self.slot)
      result.slot := add(keccak256(0, 0x20), mul(pos, 2))
    }
  }
}
