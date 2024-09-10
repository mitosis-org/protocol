// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { GovernorSettingsUpgradeable } from '@ozu-v5/governance/extensions/GovernorSettingsUpgradeable.sol';
import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';

import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { GovernorTWABVotesQuorumFractionUpgradeable } from
  '../../governance/GovernorTWABVotesQuorumFractionUpgradeable.sol';
import { GovernorTWABVotesUpgradeable } from '../../governance/GovernorTWABVotesUpgradeable.sol';
import { GovernorCountingBravoUpgradeable } from '../../governance/GovernorCountingBravoUpgradeable.sol';

// TODO(thai): Consider the way all EOL governances for different tokens are managed by only one governor contract.

contract EOLGovernor is
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  GovernorUpgradeable,
  GovernorTWABVotesUpgradeable,
  GovernorTWABVotesQuorumFractionUpgradeable,
  GovernorCountingBravoUpgradeable,
  GovernorSettingsUpgradeable
{
  bytes32 public constant PROPOSER_ROLE = keccak256('PROPOSER_ROLE');

  modifier onlyProposer() {
    _checkRole(PROPOSER_ROLE);
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address owner_,
    string memory name_,
    ITWABSnapshots token_,
    uint32 twabPeriod_,
    uint32 quorumFraction_,
    uint32 votingDelay_,
    uint32 votingPeriod_,
    uint32 proposalThreshold_
  ) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, owner_);

    __Governor_init(name_);
    __GovernorTWABVotes_init(token_, twabPeriod_);
    __GovernorTWABVotesQuorumFraction_init(quorumFraction_);
    __GovernorCountingBravo_init();
    __GovernorSettings_init(votingDelay_, votingPeriod_, proposalThreshold_);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override onlyProposer returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
    return GovernorSettingsUpgradeable.proposalThreshold();
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable, GovernorUpgradeable)
    returns (bool)
  {
    return AccessControlUpgradeable.supportsInterface(interfaceId) || GovernorUpgradeable.supportsInterface(interfaceId);
  }
}
