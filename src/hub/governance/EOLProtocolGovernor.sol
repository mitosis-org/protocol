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
// TODO(thai): consider ERC-1271 (castVoteBySig) for voting.

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

  function initialize(address owner, IEOLProtocolRegistry protocolRegistry_, address eolVault_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);

    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, owner);

    StorageV1 storage $ = _getStorageV1();
    $.protocolRegistry = protocolRegistry_;
    $.eolVault = eolVault_;
  }

  function proposalId(ProposalType proposalType, bytes memory payload, string memory description)
    external
    pure
    returns (uint256)
  {
    return _proposalId(proposalType, payload, description);
  }

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
    )
  {
    StorageV1 storage $ = _getStorageV1();

    Proposal storage p = $.proposals[proposalId_];
    require(p.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId_));

    return (p.proposer, p.proposalType, p.startsAt, p.endsAt, p.payload, p.executed);
  }

  function voteOption(uint256 proposalId_, address account) external view returns (VoteOption) {
    StorageV1 storage $ = _getStorageV1();
    Proposal storage p = $.proposals[proposalId_];

    require(p.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId_));
    return p.votes[account];
  }

  function proposeInitiation(
    uint48 startsAt,
    uint48 endsAt,
    InitiationProposalPayload memory payload,
    string memory description
  ) external onlyProposer returns (uint256 proposalId_) {
    StorageV1 storage $ = _getStorageV1();

    bytes memory payload_ = abi.encode(payload);
    proposalId_ = _proposalId(ProposalType.Initiation, payload_, description);
    _assertProposalNotExist($, proposalId_);

    Proposal storage p = $.proposals[proposalId_];
    p.proposer = _msgSender();
    p.proposalType = ProposalType.Initiation;
    p.startsAt = startsAt;
    p.endsAt = endsAt;
    p.payload = payload_;

    emit ProposalCreated(proposalId_, _msgSender(), ProposalType.Initiation, startsAt, endsAt, payload_, description);
  }

  function proposeDeletion(
    uint48 startsAt,
    uint48 endsAt,
    DeletionProposalPayload memory payload,
    string memory description
  ) external onlyProposer returns (uint256 proposalId_) {
    StorageV1 storage $ = _getStorageV1();
    bytes memory payload_ = abi.encode(payload);

    proposalId_ = _proposalId(ProposalType.Deletion, payload_, description);
    _assertProposalNotExist($, proposalId_);

    Proposal storage p = $.proposals[proposalId_];
    p.proposer = _msgSender();
    p.proposalType = ProposalType.Deletion;
    p.startsAt = startsAt;
    p.endsAt = endsAt;
    p.payload = payload_;

    emit ProposalCreated(proposalId_, _msgSender(), ProposalType.Deletion, startsAt, endsAt, payload_, description);
  }

  function castVote(uint256 proposalId_, VoteOption option) external {
    _assertVoteOptionValid(option);

    StorageV1 storage $ = _getStorageV1();
    Proposal storage p = $.proposals[proposalId_];

    require(p.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId_));
    require(p.startsAt <= block.timestamp, IEOLProtocolGovernor__ProposalNotStarted());
    require(p.endsAt > block.timestamp, IEOLProtocolGovernor__ProposalEnded());

    p.votes[_msgSender()] = option;

    emit VoteCasted(proposalId_, _msgSender(), option);
  }

  function execute(uint256 proposalId_) external {
    StorageV1 storage $ = _getStorageV1();
    Proposal storage p = $.proposals[proposalId_];

    require(p.proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId_));
    require(p.proposer != _msgSender(), IEOLProtocolGovernor__InvalidExecutor(p.proposer));
    require(p.endsAt <= block.timestamp, IEOLProtocolGovernor__ProposalNotEnded());
    require(!p.executed, IEOLProtocolGovernor__ProposalAlreadyExecuted());

    p.executed = true;

    if (p.proposalType == ProposalType.Initiation) {
      InitiationProposalPayload memory payload = abi.decode(p.payload, (InitiationProposalPayload));
      $.protocolRegistry.registerProtocol(payload.eolVault, payload.chainId, payload.name, payload.metadata);
    } else if (p.proposalType == ProposalType.Deletion) {
      DeletionProposalPayload memory payload = abi.decode(p.payload, (DeletionProposalPayload));
      uint256 protocolId = $.protocolRegistry.protocolId(payload.eolVault, payload.chainId, payload.name);
      $.protocolRegistry.unregisterProtocol(protocolId);
    } else {
      revert IEOLProtocolGovernor__InvalidProposalType(p.proposalType);
    }

    emit ProposalExecuted(proposalId_);
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

  function _assertProposalExists(StorageV1 storage $, uint256 proposalId_) internal view {
    require($.proposals[proposalId_].proposer != address(0), IEOLProtocolGovernor__ProposalNotExist(proposalId_));
  }

  function _assertProposalNotExist(StorageV1 storage $, uint256 proposalId_) internal view {
    require($.proposals[proposalId_].proposer == address(0), IEOLProtocolGovernor__ProposalAlreadyExists(proposalId_));
  }

  function _assertVoteOptionValid(VoteOption option) internal pure {
    require(
      option == VoteOption.Yes || option == VoteOption.No || option == VoteOption.Abstain,
      IEOLProtocolGovernor__InvalidVoteOption(option)
    );
  }
}
