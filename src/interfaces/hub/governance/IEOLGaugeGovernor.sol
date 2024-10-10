// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IEOLGaugeGovernor
 * @dev Interface for the EOL Gauge Governor, which manages voting and gauge allocation for EOL protocols.
 */
interface IEOLGaugeGovernor {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event EpochStarted(uint256 indexed epochId, uint48 startsAt, uint48 endsAt);
  event ProtocolIdsFetched(uint256 indexed epochId, uint256 indexed chainId, uint256[] protocolIds);
  event VoteCasted(uint256 indexed epochId, uint256 indexed chainId, address indexed account, uint32[] gauges);

  event EpochPeriodSet(uint32 epochPeriod);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IEOLGaugeGovernor__EpochNotFound(uint256 epochId);
  error IEOLGaugeGovernor__EpochNotOngoing(uint256 epochId);

  error IEOLGaugeGovernor__ZeroGaugesLength();
  error IEOLGaugeGovernor__InvalidGaugesLength(uint256 actual, uint256 expected);
  error IEOLGaugeGovernor__InvalidGaugesSum();

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function voters(uint256 chainId) external view returns (address[] memory);

  /**
   * @notice Returns the ID of the last epoch.
   * @return The ID of the last epoch.
   */
  function lastEpochId() external view returns (uint256);

  function protocolIds(uint256 epochId, uint256 chainId) external view returns (uint256[] memory);

  /**
   * @notice Retrieves the vote result for a specific epoch, chain, and account.
   * @param epochId The ID of the epoch.
   * @param chainId The ID of the chain.
   * @param account The address of the account.
   * @return hasVoted Boolean indicating if the account has voted.
   * @return gaugeSum The sum of gauge values voted by the account.
   * @return gauges An array of gauge values voted by the account.
   */
  function voteResult(uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 gaugeSum, uint32[] memory gauges);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @notice Casts a vote for a specific chain and set of gauges.
   * @param chainId The ID of the chain.
   * @param gauges An array of gauge values to vote for.
   */
  function castVote(uint256 chainId, uint32[] memory gauges) external;
}
