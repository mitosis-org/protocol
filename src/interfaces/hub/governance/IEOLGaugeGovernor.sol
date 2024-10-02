// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IEOLGaugeGovernor
 * @author Manythings Pte. Ltd.
 * @dev Interface for the EOL Gauge Governor, which manages voting and gauge allocation for EOL protocols.
 */
interface IEOLGaugeGovernor {
  /**
   * @notice Retrieves the list of voters for a specific chain.
   * @param chainId The ID of the chain.
   * @return An array of voter addresses.
   */
  function voters(uint256 chainId) external view returns (address[] memory);

  /**
   * @notice Returns the ID of the last epoch.
   * @return The ID of the last epoch.
   */
  function lastEpochId() external view returns (uint256);

  /**
   * @notice Returns the total voting power for a specific epoch.
   * @param epochId The ID of the epoch.
   * @return The total voting power for the epoch.
   */
  function totalVotingPower(uint256 epochId) external view returns (uint256);

  /**
   * @notice Retrieves the protocol IDs for a specific epoch and chain.
   * @param epochId The ID of the epoch.
   * @param chainId The ID of the chain.
   * @return An array of protocol IDs.
   */
  function protocolIds(uint256 epochId, uint256 chainId) external view returns (uint256[] memory);

  /**
   * @notice Retrieves the vote result for a specific epoch, chain, and account.
   * @param epochId The ID of the epoch.
   * @param chainId The ID of the chain.
   * @param account The address of the account.
   * @return hasVoted Boolean indicating if the account has voted.
   * @return votingPower The voting power of the account.
   * @return gaugeSum The sum of gauge values voted by the account.
   * @return gauges An array of gauge values voted by the account.
   */
  function voteResult(uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 votingPower, uint256 gaugeSum, uint32[] memory gauges);

  /**
   * @notice Casts a vote for a specific chain and set of gauges.
   * @param chainId The ID of the chain.
   * @param gauges An array of gauge values to vote for.
   */
  function castVote(uint256 chainId, uint32[] memory gauges) external;

  /**
   * @notice Sets the period for epochs.
   * @param epochPeriod The new period for epochs.
   */
  function setEpochPeriod(uint32 epochPeriod) external;
}
