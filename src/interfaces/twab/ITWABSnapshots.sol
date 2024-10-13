// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC5805 } from '@oz-v5/interfaces/IERC5805.sol';

/**
 * @title ITWABSnapshots
 * @notice Interface for Time-Weighted Average Balance (TWAB) snapshots functionality
 * @dev This interface overrides the IERC5805 interface to satisfy the voting power delegation requirements
 */
interface ITWABSnapshots is IERC5805 {
  /**
   * @dev Error thrown when the ERC6372 clock is inconsistent.
   */
  error ERC6372InconsistentClock();

  /**
   * @dev Error thrown when trying to lookup a future timepoint.
   * @param timestamp The requested timestamp.
   * @param now_ The current timestamp.
   */
  error ERC5805FutureLookup(uint256 timestamp, uint256 now_);

  /**
   * @notice Returns the total supply snapshot at the current time.
   * @return balance The current total supply.
   * @return twab Accumulated time-weighted average balance of the total supply.
   * @return position The timestamp of the snapshot.
   */
  function totalSupplySnapshot() external view returns (uint208 balance, uint256 twab, uint48 position);

  /**
   * @notice Returns the total supply snapshot at a specific timepoint.
   * @param timepoint The timestamp at which to get the snapshot.
   * @return balance The total supply at the given timepoint.
   * @return twab Accumulated time-weighted average balance of the total supply at the given timepoint.
   * @return position The timestamp of the snapshot.
   */
  function totalSupplySnapshot(uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);

  /**
   * @notice Returns the balance snapshot for an account at a specific timepoint.
   * @param account The address of the account.
   * @param timepoint The timestamp at which to get the snapshot.
   * @return balance The balance of the account at the given timepoint.
   */
  function balanceSnapshot(address account, uint256 timepoint) external view returns (uint208);

  /**
   * @notice Returns the delegate snapshot for an account at the current time.
   * @param account The address of the account.
   * @return balance The current balance of the account's delegate.
   * @return twab Accumulated time-weighted average balance of the account's delegate.
   * @return position The timestamp of the snapshot.
   */
  function delegateSnapshot(address account) external view returns (uint208 balance, uint256 twab, uint48 position);

  /**
   * @notice Returns the delegate snapshot for an account at a specific timepoint.
   * @param account The address of the account.
   * @param timestamp The timestamp at which to get the snapshot.
   * @return balance The balance of the account's delegate at the given timepoint.
   * @return twab Accumulated time-weighted average balance of the account's delegate at the given timepoint.
   * @return position The timestamp of the snapshot.
   */
  function delegateSnapshot(address account, uint256 timestamp)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);

  /**
   * @notice Marks the account's delegatee by the manager account
   * @dev This function should only be callable by the nominated manager account (see IDelegationRegistry)
   * @param account The address of the account to delegate for.
   * @param delegatee The address to delegate to.
   */
  function delegateByManager(address account, address delegatee) external;
}
