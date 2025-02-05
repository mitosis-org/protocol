// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ISnapshots
 * @notice Interface for snapshots functionality
 */
interface ISnapshots {
  /**
   * @dev Error thrown when the ERC6372 clock is inconsistent.
   */
  error ERC6372InconsistentClock();

  /**
   * @dev Error thrown when the timestamp is greater than the current timestamp.
   */
  error ERC5805FutureLookup(uint256 timestamp, uint256 currentTimestamp);

  /**
   * @notice Returns the current timestamp of the snapshot.
   */
  function clock() external view returns (uint48);

  //=========== NOTE: Snapshot & Delegation ===========//

  /**
   * @notice Returns the total supply snapshot at a specific timepoint.
   * @param timepoint The timestamp at which to get the snapshot.
   * @return balance The total supply at the given timepoint.
   */
  function totalSupplySnapshot(uint256 timepoint) external view returns (uint208);

  /**
   * @notice Returns the balance snapshot for an account at a specific timepoint.
   * @param account The address of the account.
   * @param timepoint The timestamp at which to get the snapshot.
   * @return balance The balance of the account at the given timepoint.
   */
  function balanceSnapshot(address account, uint256 timepoint) external view returns (uint208);
}
