// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { GovernorSettingsUpgradeable } from '@ozu-v5/governance/extensions/GovernorSettingsUpgradeable.sol';
import { GovernorStorageUpgradeable } from '@ozu-v5/governance/extensions/GovernorStorageUpgradeable.sol';
import { GovernorTimelockControlUpgradeable } from
  '@ozu-v5/governance/extensions/GovernorTimelockControlUpgradeable.sol';
import { GovernorVotesQuorumFractionUpgradeable } from
  '@ozu-v5/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol';
import { GovernorVotesUpgradeable } from '@ozu-v5/governance/extensions/GovernorVotesUpgradeable.sol';
import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';
import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';

import { GovernorCountingBravoUpgradeable } from './GovernorCountingBravoUpgradeable.sol';

contract MITOGovernance is
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  GovernorUpgradeable,
  GovernorSettingsUpgradeable,
  GovernorCountingBravoUpgradeable,
  GovernorStorageUpgradeable,
  GovernorVotesUpgradeable,
  GovernorVotesQuorumFractionUpgradeable,
  GovernorTimelockControlUpgradeable
{
  bytes32 public constant PROPOSER_ROLE = keccak256('PROPOSER_ROLE');

  /**
   * @dev Granting a role to `address(0)` is equivalent to enabling the role for everyone.
   */
  modifier onlyProposer() {
    if (!hasRole(PROPOSER_ROLE, address(0))) {
      _checkRole(PROPOSER_ROLE);
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(
    IVotes token_,
    TimelockControllerUpgradeable timelock_,
    uint32 votingDelay_,
    uint32 votingPeriod_,
    uint32 proposalThreshold_,
    uint32 quorumFraction_
  ) public initializer {
    __AccessControl_init();

    __Governor_init('MITOGovernance');
    __GovernorSettings_init(votingDelay_, votingPeriod_, proposalThreshold_);
    __GovernorCountingBravo_init();
    __GovernorStorage_init();
    __GovernorVotes_init(token_);
    __GovernorVotesQuorumFraction_init(quorumFraction_);
    __GovernorTimelockControl_init(timelock_);
  }

  function hasRole(bytes32 role, address account) public view override returns (bool) {
    // Allow the executor to bypass role checks
    if (account == _executor()) return true;
    return super.hasRole(role, account);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override onlyProposer returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable, GovernorUpgradeable)
    returns (bool)
  {
    return AccessControlUpgradeable.supportsInterface(interfaceId) || GovernorUpgradeable.supportsInterface(interfaceId);
  }

  function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
    return GovernorSettingsUpgradeable.proposalThreshold();
  }

  function state(uint256 proposalId)
    public
    view
    override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    returns (ProposalState)
  {
    return GovernorTimelockControlUpgradeable.state(proposalId);
  }

  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    returns (bool)
  {
    return GovernorTimelockControlUpgradeable.proposalNeedsQueuing(proposalId);
  }

  function _propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    address proposer
  ) internal override(GovernorUpgradeable, GovernorStorageUpgradeable) returns (uint256) {
    return GovernorStorageUpgradeable._propose(targets, values, calldatas, description, proposer);
  }

  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
    return GovernorTimelockControlUpgradeable._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
    GovernorTimelockControlUpgradeable._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    internal
    override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    returns (uint256)
  {
    return GovernorTimelockControlUpgradeable._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executor()
    internal
    view
    override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    returns (address)
  {
    return GovernorTimelockControlUpgradeable._executor();
  }
}
