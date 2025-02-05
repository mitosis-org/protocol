// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ITWABSnapshots
 * @notice Interface for Time-Weighted Average Balance (TWAB) snapshots functionality
 */
interface ITWABSnapshots {
  /**
   * @dev Error thrown when the ERC6372 clock is inconsistent.
   */
  error ERC6372InconsistentClock();

  //=========== NOTE: Snapshot & Delegation ===========//

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

  //=========== NOTE: TWAB ===========//

  /**
   * @notice Returns the Time-Weighted Average Balance (TWAB) for an account between two timepoints.
   * @param account The address of the account.
   * @param startsAt The timestamp at which to start the TWAB calculation.
   * @param endsAt The timestamp at which to end the TWAB calculation.
   */
  function getTWABByTimestampRange(address account, uint48 startsAt, uint48 endsAt) external view returns (uint256);

  /**
   * @notice Returns the Time-Weighted Average Balance (TWAB) for the total supply between two timepoints.
   * @param startsAt The timestamp at which to start the TWAB calculation.
   * @param endsAt The timestamp at which to end the TWAB calculation.
   */
  function getTotalTWABByTimestampRange(uint48 startsAt, uint48 endsAt) external view returns (uint256);
}
