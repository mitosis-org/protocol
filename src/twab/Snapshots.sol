// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IERC6372 } from '@openzeppelin/contracts/interfaces/IERC6372.sol';
import { SafeCast } from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import { Time } from '@openzeppelin/contracts/utils/types/Time.sol';

import { TwabCheckpoints } from '../lib/TwabCheckpoints.sol';

abstract contract Snapshots is IERC6372 {
  using TwabCheckpoints for TwabCheckpoints.Trace;

  mapping(address account => TwabCheckpoints.Trace) _accountCheckpoints;

  TwabCheckpoints.Trace private _totalCheckpoints;

  error ERC6372InconsistentClock();

  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

  function clock() public view virtual returns (uint48) {
    return Time.timestamp();
  }

  function CLOCK_MODE() public view virtual returns (string memory) {
    // Check that the clock was not modified
    if (clock() != Time.timestamp()) {
      revert ERC6372InconsistentClock();
    }
    return 'mode=timestamp';
  }

  function _snapshot(address from, address to, uint256 amount) internal virtual {
    if (from != to && amount > 0) {
      if (from == address(0)) {
        _push(_totalCheckpoints, _add, SafeCast.toUint208(amount));
      } else {
        _push(_accountCheckpoints[from], _subtract, SafeCast.toUint208(amount));
      }

      if (to == address(0)) {
        _push(_totalCheckpoints, _subtract, SafeCast.toUint208(amount));
      } else {
        _push(_accountCheckpoints[to], _add, SafeCast.toUint208(amount));
      }
    }
  }

  function getLatestSnapshot(address account)
    public
    view
    virtual
    returns (uint208 balnace, uint256 twab, uint48 position)
  {
    return _accountCheckpoints[account].latest();
  }

  function getPastSnapshot(address account, uint256 timestamp)
    public
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    if (timestamp >= currentTimestamp) {
      revert ERC5805FutureLookup(timestamp, currentTimestamp);
    }
    return _accountCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function getLastestTotalSnapshot() public view virtual returns (uint208 balance, uint256 twab, uint48 position) {
    return _totalCheckpoints.latest();
  }

  function getPastTotalSnapshot(uint256 timestamp)
    public
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    if (timestamp >= currentTimestamp) {
      revert ERC5805FutureLookup(timestamp, currentTimestamp);
    }
    return _totalCheckpoints.upperLookupRecent(SafeCast.toUint48(timestamp));
  }

  function _push(
    TwabCheckpoints.Trace storage store,
    function(uint208, uint208) view returns (uint208) op,
    uint208 delta
  ) private returns (uint208, uint208, uint256, uint256) {
    (uint208 lastBalance, uint256 lastTwab, uint48 lastPosition) = store.latest();

    uint208 balance = op(lastBalance, delta);

    uint256 twab = lastTwab;
    // TWAB is a cumulative value, so it is not affected by the current balance.
    if (lastPosition < block.timestamp) {
      twab = _calcAccumulatedTwab(lastTwab, lastBalance, block.timestamp - lastPosition);
    }

    return store.push(clock(), balance, twab);
  }

  function _calcAccumulatedTwab(uint256 lastTwab, uint208 lastBalance, uint256 duration) private pure returns (uint256) {
    return lastTwab + (lastBalance * duration);
  }

  function _add(uint208 a, uint208 b) private pure returns (uint208) {
    return a + b;
  }

  function _subtract(uint208 a, uint208 b) private pure returns (uint208) {
    return a - b;
  }
}
