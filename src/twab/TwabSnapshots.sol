// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { ITwabSnapshots } from '../interfaces/twab/ITwabSnapshots.sol';
import { TwabCheckpoints } from '../lib/TwabCheckpoints.sol';
import { TwabSnapshotsStorageV1 } from './TwabSnapshotsStorageV1.sol';

abstract contract TwabSnapshots is ITwabSnapshots, IERC6372, TwabSnapshotsStorageV1 {
  using TwabCheckpoints for TwabCheckpoints.Trace;

  error ERC6372InconsistentClock();

  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    if (clock() != Time.timestamp()) {
      revert ERC6372InconsistentClock();
    }
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
    return _getTwabSnapshotStorageV1().accountCheckpoints[account].latest();
  }

  function getPastSnapshot(address account, uint256 timestamp)
    external
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    if (timestamp >= currentTimestamp) {
      revert ERC5805FutureLookup(timestamp, currentTimestamp);
    }
    return _getTwabSnapshotStorageV1().accountCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function getLatestTotalSnapshot() external view virtual returns (uint208 balance, uint256 twab, uint48 position) {
    return _getTwabSnapshotStorageV1().totalCheckpoints.latest();
  }

  function getPastTotalSnapshot(uint256 timestamp)
    external
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    if (timestamp >= currentTimestamp) {
      revert ERC5805FutureLookup(timestamp, currentTimestamp);
    }
    return _getTwabSnapshotStorageV1().totalCheckpoints.upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function _snapshot(address from, address to, uint256 amount) internal virtual {
    TwabSnapshotStorageV1 storage $ = _getTwabSnapshotStorageV1();

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
    TwabCheckpoints.Trace storage store,
    function(uint208, uint208) view returns (uint208) op,
    uint208 delta
  ) private returns (uint208, uint208, uint256, uint256) {
    (uint208 lastBalance, uint256 lastTwab, uint48 lastPosition) = store.latest();

    uint208 balance = op(lastBalance, delta);

    uint256 twab = lastTwab;
    uint48 timestamp = clock();
    // TWAB is a cumulative value, so it is not affected by the current balance.
    if (timestamp > lastPosition) {
      twab = _calcAccumulatedTwab(lastTwab, lastBalance, timestamp - lastPosition);
    }

    return TwabCheckpoints.push(store, timestamp, balance, twab);
  }

  function _calcAccumulatedTwab(uint256 lastTwab, uint208 lastBalance, uint48 duration) private pure returns (uint256) {
    return lastTwab + (lastBalance * duration);
  }

  function _add(uint208 a, uint208 b) private pure returns (uint208) {
    return a + b;
  }

  function _sub(uint208 a, uint208 b) private pure returns (uint208) {
    return a - b;
  }
}
