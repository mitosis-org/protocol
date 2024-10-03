// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { GovernorSettingsUpgradeable } from '@ozu-v5/governance/extensions/GovernorSettingsUpgradeable.sol';
import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';

import {
  IEOLProtocolGovernor,
  ProposalType,
  InitiationProposalPayload,
  DeletionProposalPayload,
  VoteOption
} from '../../interfaces/hub/governance/IEOLProtocolGovernor.sol';
import { IEOLProtocolRegistry } from '../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { EOLProtocolGovernorStorageV1, Proposal } from './EOLProtocolGovernorStorageV1.sol';

// TODO(thai): Consider the way all EOL governances for different tokens are managed by only one governor contract.
// TODO(thai): Consider better design.
//  - e.g. consider to store proposal state (passed / rejected) on-chain even though the state is calculated off-chain.
//  - e.g. consider to store quorum and threshold on-chain even though they are only used in off-chain.

contract EOLProtocolGovernor is
  IEOLProtocolGovernor,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  EOLProtocolGovernorStorageV1
{
  bytes32 public constant PROPOSER_ROLE = keccak256('PROPOSER_ROLE');

  modifier onlyProposer() {
    _checkRole(PROPOSER_ROLE);
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner, IEOLProtocolRegistry protocolRegistry_, address eolVault_, uint32 twabPeriod_)
    public
    initializer
  {
    __Ownable2Step_init();
    _transferOwnership(owner);

    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, owner);

    StorageV1 storage $ = _getStorageV1();
    $.protocolRegistry = protocolRegistry_;
    $.eolVault = eolVault_;
    $.twabPeriod = twabPeriod_;
  }

  function proposeInitiation(
    uint48 startsAt,
    uint48 endsAt,
    InitiationProposalPayload memory payload,
    string memory description
  ) external onlyProposer returns (uint256 proposalId) {
    StorageV1 storage $ = _getStorageV1();

    bytes memory payload_ = abi.encode(payload);
    proposalId = _proposalId(ProposalType.Initiation, payload_, description);
    _assertProposalNotExist($, proposalId);

    Proposal storage proposal = $.proposals[proposalId];
    proposal.proposer = _msgSender();
    proposal.proposalType = ProposalType.Initiation;
    proposal.startsAt = startsAt;
    proposal.endsAt = endsAt;
    proposal.payload = payload_;

    emit ProposalCreated(proposalId, _msgSender(), ProposalType.Initiation, startsAt, endsAt, payload_, description);
  }

  function proposeDeletion(
    uint48 startsAt,
    uint48 endsAt,
    DeletionProposalPayload memory payload,
    string memory description
  ) external onlyProposer returns (uint256 proposalId) {
    StorageV1 storage $ = _getStorageV1();
    bytes memory payload_ = abi.encode(payload);

    proposalId = _proposalId(ProposalType.Deletion, payload_, description);
    _assertProposalNotExist($, proposalId);

    Proposal storage proposal = $.proposals[proposalId];
    proposal.proposer = _msgSender();
    proposal.proposalType = ProposalType.Deletion;
    proposal.startsAt = startsAt;
    proposal.endsAt = endsAt;
    proposal.payload = payload_;

    emit ProposalCreated(proposalId, _msgSender(), ProposalType.Deletion, startsAt, endsAt, payload_, description);
  }

  function castVote(uint256 proposalId, VoteOption option) external {
    _assertVoteOptionValid(option);

    StorageV1 storage $ = _getStorageV1();
    Proposal storage proposal = $.proposals[proposalId];

    require(proposal.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId));
    require(proposal.startsAt <= block.timestamp, IEOLProtocolGovernor__ProposalNotStarted());
    require(proposal.endsAt > block.timestamp, IEOLProtocolGovernor__ProposalEnded());

    proposal.votes[_msgSender()] = option;

    emit VoteCasted(proposalId, _msgSender(), option);
  }

  function execute(uint256 proposalId) external {
    StorageV1 storage $ = _getStorageV1();
    Proposal storage proposal = $.proposals[proposalId];

    require(proposal.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId));
    require(proposal.proposer != _msgSender(), IEOLProtocolGovernor__InvalidExecutor(proposal.proposer));
    require(proposal.endsAt <= block.timestamp, IEOLProtocolGovernor__ProposalNotEnded());
    require(!proposal.executed, IEOLProtocolGovernor__ProposalAlreadyExecuted());

    proposal.executed = true;

    if (proposal.proposalType == ProposalType.Initiation) {
      InitiationProposalPayload memory payload = abi.decode(proposal.payload, (InitiationProposalPayload));
      $.protocolRegistry.registerProtocol(payload.eolVault, payload.chainId, payload.name, payload.metadata);
    } else if (proposal.proposalType == ProposalType.Deletion) {
      DeletionProposalPayload memory payload = abi.decode(proposal.payload, (DeletionProposalPayload));
      uint256 protocolId = $.protocolRegistry.protocolId(payload.eolVault, payload.chainId, payload.name);
      $.protocolRegistry.unregisterProtocol(protocolId);
    } else {
      revert IEOLProtocolGovernor__InvalidProposalType(proposal.proposalType);
    }

    emit ProposalExecuted(proposalId);
  }

  function _proposalId(ProposalType proposalType, bytes memory payload, string memory description)
    internal
    pure
    returns (uint256)
  {
    bytes32 payloadHash = keccak256(payload);
    bytes32 descriptionHash = keccak256(bytes(description));
    return uint256(keccak256(abi.encode(proposalType, payloadHash, descriptionHash)));
  }

  function _assertProposalExists(StorageV1 storage $, uint256 proposalId) internal view {
    require($.proposals[proposalId].proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId));
  }

  function _assertProposalNotExist(StorageV1 storage $, uint256 proposalId) internal view {
    require($.proposals[proposalId].proposer == address(0), IEOLProtocolGovernor__ProposalAlreadyExists(proposalId));
  }

  function _assertVoteOptionValid(VoteOption option) internal pure {
    require(
      option == VoteOption.Yes || option == VoteOption.No || option == VoteOption.Abstain,
      IEOLProtocolGovernor__InvalidVoteOption(option)
    );
  }
}
