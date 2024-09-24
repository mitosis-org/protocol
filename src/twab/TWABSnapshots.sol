// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { ITWABSnapshots } from '../interfaces/twab/ITWABSnapshots.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { TWABSnapshotsStorageV1 } from './TWABSnapshotsStorageV1.sol';

abstract contract TWABSnapshots is ITWABSnapshots, TWABSnapshotsStorageV1 {
  using TWABCheckpoints for TWABCheckpoints.Trace;

  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  function clock() public view virtual returns (uint48) {
    return Time.timestamp();
  }

  function getLatestSnapshot(address account)
    external
    view
    virtual
    returns (uint208 balnace, uint256 twab, uint48 position)
  {
    return _getTWABSnapshotsStorageV1().accountCheckpoints[account].latest();
  }

  function getPastSnapshot(address account, uint256 timestamp)
    external
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    require(timestamp < currentTimestamp, ERC5805FutureLookup(timestamp, currentTimestamp));
    return _getTWABSnapshotsStorageV1().accountCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function getLatestTotalSnapshot() external view virtual returns (uint208 balance, uint256 twab, uint48 position) {
    return _getTWABSnapshotsStorageV1().totalCheckpoints.latest();
  }

  function getPastTotalSnapshot(uint256 timestamp)
    public
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    require(timestamp < currentTimestamp, ERC5805FutureLookup(timestamp, currentTimestamp));
    return _getTWABSnapshotsStorageV1().totalCheckpoints.upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function _snapshot(address from, address to, uint256 amount) internal virtual {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    if (from != to && amount > 0) {
      if (from == address(0)) {
        _push($.totalCheckpoints, _add, SafeCast.toUint208(amount));
      } else {
        _push($.accountCheckpoints[from], _sub, SafeCast.toUint208(amount));
      }

      if (to == address(0)) {
        _push($.totalCheckpoints, _sub, SafeCast.toUint208(amount));
      } else {
        _push($.accountCheckpoints[to], _add, SafeCast.toUint208(amount));
      }
    }
  }

  function _push(
    TWABCheckpoints.Trace storage store,
    function(uint208, uint208) view returns (uint208) op,
    uint208 delta
  ) private returns (uint208, uint208, uint256, uint256) {
    (uint208 lastBalance, uint256 lastTWAB, uint48 lastPosition) = store.latest();

    uint208 balance = op(lastBalance, delta);

    uint256 twab = lastTWAB;
    uint48 timestamp = clock();
    // TWAB is a cumulative value, so it is not affected by the current balance.
    if (timestamp > lastPosition) {
      twab = _calcAccumulatedTWAB(lastTWAB, lastBalance, timestamp - lastPosition);
    }

    return TWABCheckpoints.push(store, timestamp, balance, twab);
  }

  function _calcAccumulatedTWAB(uint256 lastTWAB, uint208 lastBalance, uint48 duration) private pure returns (uint256) {
    return lastTWAB + (lastBalance * duration);
  }

  function _add(uint208 a, uint208 b) private pure returns (uint208) {
    return a + b;
  }

  function _sub(uint208 a, uint208 b) private pure returns (uint208) {
    return a - b;
  }
}
