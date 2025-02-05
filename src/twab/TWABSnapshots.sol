// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { ITWABSnapshots } from '../interfaces/twab/ITWABSnapshots.sol';
import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { TWABSnapshotsStorageV1 } from './TWABSnapshotsStorageV1.sol';

abstract contract TWABSnapshots is
  ITWABSnapshots,
  ContextUpgradeable,
  EIP712Upgradeable,
  NoncesUpgradeable,
  TWABSnapshotsStorageV1
{
  using SafeCast for uint256;
  using Checkpoints for Checkpoints.Trace208;
  using TWABCheckpoints for TWABCheckpoints.Trace;

  // ================== NOTE: Initializer ================== //

  function __TWABSnapshots_init() internal {
    __EIP712_init_unchained('TWABSnapshots', '1');
    __Nonces_init_unchained();
    __Context_init_unchained();
  }

  // ================== NOTE: Clock implementation ================ //

  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  function clock() public view virtual override(IERC6372, TWABSnapshotsStorageV1) returns (uint48) {
    return Time.timestamp();
  }

  // ================== NOTE: View Functions (Snapshots) ================== //

  function delegationRegistry() external view returns (IDelegationRegistry) {
    return _getTWABSnapshotsStorageV1().delegationRegistry;
  }

  function totalSupplySnapshot() external view virtual returns (uint208 balance, uint256 twab, uint48 position) {
    return _getTWABSnapshotsStorageV1().totalCheckpoints.latest();
  }

  function totalSupplySnapshot(uint256 timepoint)
    external
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _totalSupplySnapshot(_getTWABSnapshotsStorageV1(), timepoint);
  }

  function balanceSnapshot(address account, uint256 timepoint) external view virtual returns (uint208) {
    return _balanceSnapshot(_getTWABSnapshotsStorageV1(), account, timepoint);
  }

  function delegateSnapshot(address account)
    external
    view
    virtual
    override
    returns (uint208 balnace, uint256 twab, uint48 position)
  {
    return _getTWABSnapshotsStorageV1().delegateCheckpoints[account].latest();
  }

  function delegateSnapshot(address account, uint256 timestamp)
    external
    view
    virtual
    override
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _delegationSnapshot(_getTWABSnapshotsStorageV1(), account, timestamp);
  }

  //=========== NOTE: View Functions (TWAB) ===========//

  function getTWABByTimestampRange(address account, uint48 startsAt, uint48 endsAt) external view returns (uint256) {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    (uint208 balanceA, uint256 twabA, uint48 positionA) = _delegationSnapshot($, account, startsAt);
    (uint208 balanceB, uint256 twabB, uint48 positionB) = _delegationSnapshot($, account, endsAt);

    twabA = _calculateTWAB(balanceA, twabA, positionA, startsAt);
    twabB = _calculateTWAB(balanceB, twabB, positionB, endsAt);

    return twabB - twabA;
  }

  function getTotalTWABByTimestampRange(uint48 startsAt, uint48 endsAt) external view returns (uint256) {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    (uint208 balanceA, uint256 twabA, uint48 positionA) = _totalSupplySnapshot($, startsAt);
    (uint208 balanceB, uint256 twabB, uint48 positionB) = _totalSupplySnapshot($, endsAt);

    twabA = _calculateTWAB(balanceA, twabA, positionA, startsAt);
    twabB = _calculateTWAB(balanceB, twabB, positionB, endsAt);

    return twabB - twabA;
  }

  function _snapshotBalance(TWABSnapshotsStorageV1_ storage $, address from, address to) internal {
    if (from == address(0) || to == address(0)) _push($.totalCheckpoints, _replace, _getTotalSupply().toUint208());

    uint48 currentTimestamp = clock();
    if (from != address(0)) $.balanceCheckpoints[from].push(currentTimestamp, _getBalance(from).toUint208());
    if (to != address(0)) $.balanceCheckpoints[to].push(currentTimestamp, _getBalance(to).toUint208());
  }

  function _push(
    TWABCheckpoints.Trace storage store,
    function(uint208, uint208) view returns (uint208) op,
    uint208 delta
  ) internal virtual returns (uint208 lastBalance_, uint208 currentBalance_, uint256 lastTWAB_, uint256 currentTWAB_) {
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

  function _calcAccumulatedTWAB(uint256 lastTWAB, uint208 lastBalance, uint48 duration) internal pure returns (uint256) {
    return lastTWAB + (lastBalance * duration);
  }

  function _calculateTWAB(uint208 balance, uint256 twab, uint48 position, uint48 timestamp)
    internal
    pure
    returns (uint256)
  {
    if (position < timestamp) {
      uint256 diff = timestamp - position;
      twab += balance * diff;
    }
    return twab;
  }

  function _replace(uint208, uint208 to) private pure returns (uint208) {
    return to;
  }

  function _unsafeAdd(uint208 a, uint208 b) private pure returns (uint208) {
    unchecked {
      return a + b;
    }
  }

  function _unsafeSub(uint208 a, uint208 b) private pure returns (uint208) {
    unchecked {
      return a - b;
    }
  }

  /**
   * @dev Must return the total units held by an account.
   */
  function _getTotalSupply() internal view virtual returns (uint256);

  /**
   * @dev Must return the balance units held by an account.
   */
  function _getBalance(address) internal view virtual returns (uint256);
}
