// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { SnapshotsStorageV1 } from './SnapshotsStorageV1.sol';

abstract contract Snapshots is ContextUpgradeable, EIP712Upgradeable, NoncesUpgradeable, SnapshotsStorageV1 {
  using SafeCast for uint256;
  using Checkpoints for Checkpoints.Trace208;
  using TWABCheckpoints for TWABCheckpoints.Trace;

  // ================== NOTE: Initializer ================== //

  function __Snapshots_init() internal {
    __EIP712_init_unchained('Snapshots', '1');
    __Nonces_init_unchained();
    __Context_init_unchained();
  }

  // ================== NOTE: Clock implementation ================ //

  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  function clock() public view virtual override returns (uint48) {
    return Time.timestamp();
  }

  // ================== NOTE: View Functions (Snapshots) ================== //

  function totalSupplySnapshot(uint256 timepoint) external view virtual returns (uint208) {
    return _totalSupplySnapshot(_getSnapshotsStorageV1(), timepoint);
  }

  function balanceSnapshot(address account, uint256 timepoint) external view virtual returns (uint208) {
    return _balanceSnapshot(_getSnapshotsStorageV1(), account, timepoint);
  }

  //=========== NOTE: Internal Functions ===========//

  function _snapshotBalance(SnapshotsStorageV1_ storage $, address from, address to) internal {
    uint48 currentTimestamp = clock();
    if (from == address(0) || to == address(0)) {
      $.totalCheckpoints.push(currentTimestamp, _getTotalSupply().toUint208());
    }
    if (from != address(0)) $.balanceCheckpoints[from].push(currentTimestamp, _getBalance(from).toUint208());
    if (to != address(0)) $.balanceCheckpoints[to].push(currentTimestamp, _getBalance(to).toUint208());
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
