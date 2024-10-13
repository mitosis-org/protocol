// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IEOLGaugeGovernor
 * @dev Interface for the EOL Gauge Governor, which manages voting and gauge allocation for EOL protocols.
 */
interface IEOLGaugeGovernor {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event EpochStarted(address indexed eolVault, uint256 indexed epochId, uint48 startsAt, uint48 endsAt);
  event ProtocolIdsFetched(address indexed eolVault, uint256 indexed epochId, uint256 chainId, uint256[] protocolIds);
  event VoteCasted(
    address indexed eolVault, uint256 indexed epochId, uint256 chainId, address indexed account, uint32[] gauges
  );

  event EpochPeriodSet(uint32 epochPeriod);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IEOLGaugeGovernor__GovernanceNotFound(address eolVault);
  error IEOLGaugeGovernor__GovernanceAlreadyInitialized(address eolVault);

  error IEOLGaugeGovernor__EpochNotFound(address eolVault, uint256 epochId);
  error IEOLGaugeGovernor__EpochNotOngoing(address eolVault, uint256 epochId);

  error IEOLGaugeGovernor__ZeroGaugesLength();
  error IEOLGaugeGovernor__InvalidGaugesLength(uint256 actual, uint256 expected);
  error IEOLGaugeGovernor__InvalidGaugesSum();

  //=========== NOTE: VIEW FUNCTIONS ===========//

  /**
   * @notice Returns if the governance has been initialized for a specific EOLVault.
   * @param eolVault The address of the EOLVault.
   */
  function isGovernanceInitialized(address eolVault) external view returns (bool);

  /**
   * @notice Returns the period of an epoch for a specific EOLVault.
   * @param eolVault The address of the EOLVault.
   */
  function epochPeriod(address eolVault) external view returns (uint32);

  /**
   * @notice Returns the ID of the last epoch for a specific EOLVault.
   * Note that the epoch ID starts from 1.
   * @param eolVault The address of the EOLVault.
   */
  function lastEpochId(address eolVault) external view returns (uint256);

  /**
   * @notice Returns the epoch information for a specific EOLVault and epoch ID.
   * @param eolVault The address of the EOLVault.
   * @param epochId The ID of the epoch.
   * @return startsAt The start time of the epoch.
   * @return endsAt The end time of the epoch.
   */
  function epoch(address eolVault, uint256 epochId) external view returns (uint48 startsAt, uint48 endsAt);

  /**
   * @notice Returns the protocol IDs for a specific EOLVault, epoch and chain.
   * @param eolVault The address of the EOLVault.
   * @param epochId The ID of the epoch.
   * @param chainId The ID of the chain.
   */
  function protocolIds(address eolVault, uint256 epochId, uint256 chainId) external view returns (uint256[] memory);

  /**
   * @notice Returns the addresses of voters for a specific EOLVault and chain.
   * @param eolVault The address of the EOLVault.
   * @param chainId The ID of the chain.
   */
  function voters(address eolVault, uint256 chainId) external view returns (address[] memory);

  /**
   * @notice Retrieves the vote result for a specific EOLVault, epoch, chain, and account.
   * @param eolVault The address of the EOLVault.
   * @param epochId The ID of the epoch.
   * @param chainId The ID of the chain.
   * @param account The address of the account.
   * @return hasVoted Boolean indicating if the account has voted.
   * @return gaugeSum The sum of gauge values voted by the account.
   * @return gauges An array of gauge values voted by the account.
   */
  function voteResult(address eolVault, uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 gaugeSum, uint32[] memory gauges);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @notice Casts a vote for a specific chain and set of gauges.
   * @param eolVault The address of the EOLVault.
   * @param chainId The ID of the chain.
   * @param gauges An array of gauge values to vote for.
   */
  function castVote(address eolVault, uint256 chainId, uint32[] memory gauges) external;
}
