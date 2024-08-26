// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { GovernorCountingSimpleUpgradeable } from '@ozu-v5/governance/extensions/GovernorCountingSimpleUpgradeable.sol';
import { GovernorSettingsUpgradeable } from '@ozu-v5/governance/extensions/GovernorSettingsUpgradeable.sol';
import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { ITwabSnapshots } from '../../interfaces/twab/ITwabSnapshots.sol';
import { GovernorTwabVotesUpgradeable } from '../../twab/governance/GovernorTwabVotesUpgradeable.sol';
import { GovernorTwabVotesQuorumFractionUpgradeable } from
  '../../twab/governance/GovernorTwabVotesQuorumFractionUpgradeable.sol';

// TODO(thai): Consider the way all EOL governances for different tokens are managed by only one governor contract.

contract EOLGovernor is
  Ownable2StepUpgradeable,
  GovernorUpgradeable,
  GovernorTwabVotesUpgradeable,
  GovernorTwabVotesQuorumFractionUpgradeable,
  GovernorCountingSimpleUpgradeable,
  GovernorSettingsUpgradeable
{
  constructor() {
    _disableInitializers();
  }

  function __EOLGovernor_init(
    address owner_,
    string memory name_,
    ITwabSnapshots token_,
    uint32 twabPeriod_,
    uint32 quorumFraction_,
    uint32 votingDelay_,
    uint32 votingPeriod_,
    uint32 proposalThreshold_
  ) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    __Governor_init(name_);
    __GovernorTwabVotes_init(token_, twabPeriod_);
    __GovernorTwabVotesQuorumFraction_init(quorumFraction_);
    __GovernorCountingSimple_init();
    __GovernorSettings_init(votingDelay_, votingPeriod_, proposalThreshold_);
  }

  function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
    return super.proposalThreshold();
  }

  // TODO(thai): Change RBAC for not owner but proposer to be able to propose a new proposal.
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override onlyOwner returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }
}
