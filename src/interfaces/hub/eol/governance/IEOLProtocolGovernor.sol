// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IEOLProtocolGovernor
 * @notice Interface for the contract that governs the protocol for EOLVaults (EOLProtocolGovernor)
 */
interface IEOLProtocolGovernor {
  //=========== NOTE: TYPE DEFINITIONS ===========//
  enum ProposalType {
    Initiation,
    Deletion
  }

  struct InitiationProposalPayload {
    address eolVault;
    uint256 chainId;
    string name;
    string metadata;
  }

  struct DeletionProposalPayload {
    address eolVault;
    uint256 chainId;
    string name;
  }

  enum VoteOption {
    None,
    Yes,
    No,
    Abstain
  }

  //=========== NOTE: EVENT DEFINITIONS ===========//

  event ProposalCreated(
    uint256 indexed proposalId,
    address indexed proposer,
    ProposalType proposalType,
    uint48 startsAt,
    uint48 endsAt,
    bytes payload,
    string description
  );
  event ProposalExecuted(uint256 indexed proposalId);
  event VoteCasted(uint256 indexed proposalId, address indexed account, VoteOption option);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IEOLProtocolGovernor__ProposalNotExist(uint256 proposalId);
  error IEOLProtocolGovernor__ProposalAlreadyExists(uint256 proposalId);

  error IEOLProtocolGovernor__InvalidProposalType(ProposalType proposalType);
  error IEOLProtocolGovernor__InvalidVoteOption(VoteOption option);

  error IEOLProtocolGovernor__ProposalNotStarted();
  error IEOLProtocolGovernor__ProposalEnded();
  error IEOLProtocolGovernor__ProposalNotEnded();
  error IEOLProtocolGovernor__ProposalAlreadyExecuted();

  //=========== NOTE: VIEW FUNCTIONS ===========//

  /**
   * @notice Returns the unique ID for a proposal
   * @param proposalType The type of proposal
   * @param payload The proposal payload
   * @param description The proposal description
   * @return proposalId The unique ID for the proposal, which is keccak hash of the parameters above
   */
  function proposalId(ProposalType proposalType, bytes memory payload, string memory description)
    external
    pure
    returns (uint256);

  /**
   * @notice Returns the proposal details for a given proposal ID
   * @param proposalId_ The proposal ID
   * @return proposer The address of the proposer
   * @return proposalType The type of proposal
   * @return startsAt The start time of the proposal
   * @return endsAt The end time of the proposal
   * @return payload The proposal payload necessary for executing the proposal if accepted.
   * @return executed Boolean indicating if the proposal has been executed
   */
  function proposal(uint256 proposalId_)
    external
    view
    returns (
      address proposer,
      ProposalType proposalType,
      uint48 startsAt,
      uint48 endsAt,
      bytes memory payload,
      bool executed
    );

  /**
   * @notice Returns the vote option casted by an account for a given proposal ID
   * @param proposalId_ The proposal ID
   * @param account Voter account
   */
  function voteOption(uint256 proposalId_, address account) external view returns (VoteOption);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @notice Proposes a new protocol initiation proposal
   * @dev This function can only be called by the authorized proposer
   * @param startsAt The start time of the proposal
   * @param endsAt The end time of the proposal
   * @param payload The proposal payload
   * @param description The proposal description
   * @return proposalId_ The unique ID for the proposal (see proposalId method above)
   */
  function proposeInitiation(
    uint48 startsAt,
    uint48 endsAt,
    InitiationProposalPayload memory payload,
    string memory description
  ) external returns (uint256 proposalId_);

  /**
   * @notice Proposes a new protocol deletion proposal
   * @dev This function can only be called by the authorized proposer
   * @param startsAt The start time of the proposal
   * @param endsAt The end time of the proposal
   * @param payload The proposal payload
   * @param description The proposal description
   * @return proposalId_ The unique ID for the proposal (see proposalId method above)
   */
  function proposeDeletion(
    uint48 startsAt,
    uint48 endsAt,
    DeletionProposalPayload memory payload,
    string memory description
  ) external returns (uint256 proposalId_);

  /**
   * @notice Casts a vote for a given proposal with sender account
   * @param proposalId_ The proposal ID
   * @param option The vote option
   */
  function castVote(uint256 proposalId_, VoteOption option) external;

  /**
   * @notice Executes a proposal if it has met the requirements
   * @dev This function can only be called by the authorized executor
   * @param proposalId_ The proposal ID
   * @param executionPayload The proposal execution payload
   */
  function execute(uint256 proposalId_, bytes memory executionPayload) external;
}
