// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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
    ProposalType indexed proposalType,
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

  function proposalId(ProposalType proposalType, bytes memory payload, string memory description)
    external
    pure
    returns (uint256);

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

  function voteOption(uint256 proposalId_, address account) external view returns (VoteOption);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function proposeInitiation(
    uint48 startsAt,
    uint48 endsAt,
    InitiationProposalPayload memory payload,
    string memory description
  ) external returns (uint256 proposalId_);

  function proposeDeletion(
    uint48 startsAt,
    uint48 endsAt,
    DeletionProposalPayload memory payload,
    string memory description
  ) external returns (uint256 proposalId_);

  function castVote(uint256 proposalId_, VoteOption option) external;

  function execute(uint256 proposalId_) external;
}
