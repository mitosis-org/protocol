// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from '@std/Test.sol';

import { ISudoVotes } from '../../../src/interfaces/lib/ISudoVotes.sol';
import { BranchProxyT } from '../types/BranchProxyT.sol';
import { HubConfigs } from '../types/HubConfigs.sol';
import { HubProxyT } from '../types/HubProxyT.sol';

contract Linker is Test {
  function linkHub(
    address owner,
    address admin,
    address govAdmin,
    HubProxyT.Chain memory hub,
    HubConfigs.DeployConfig memory config
  ) internal {
    address govMITOStaking = address(hub.validator.stakings[1].staking);

    // ======= LINK CONTRACT EACH OTHER ======= //
    vm.deal(owner, config.govMITOEmission.total);
    vm.startBroadcast(owner);

    hub.govMITO.setMinter(address(hub.govMITOEmission));

    hub.govMITO.setModule(govMITOStaking, true);
    hub.govMITO.setWhitelistedSender(address(hub.govMITOEmission), true);

    hub.govMITOEmission.addValidatorRewardEmission{ value: config.govMITOEmission.total }();
    hub.govMITOEmission.setValidatorRewardRecipient(address(hub.validator.rewardDistributor));

    hub.govMITOEmission.grantRole(hub.govMITOEmission.VALIDATOR_REWARD_MANAGER_ROLE(), admin);

    hub.consensusLayer.governanceEntrypoint.setPermittedCaller(address(hub.governance.mitoTimelock), true);

    hub.consensusLayer.validatorEntrypoint.setPermittedCaller(address(hub.validator.manager), true);
    hub.consensusLayer.validatorEntrypoint.setPermittedCaller(address(hub.validator.stakingHub), true);

    for (uint256 i = 0; i < hub.validator.stakings.length; i++) {
      address staking = address(hub.validator.stakings[i].staking);
      hub.validator.stakingHub.addNotifier(staking);
    }

    hub.govMITO.setDelegationManager(address(hub.governance.mitoVP));
    ISudoVotes(govMITOStaking).setDelegationManager(address(hub.governance.mitoVP));

    hub.validator.contributionFeed.grantRole(hub.validator.contributionFeed.FEEDER_ROLE(), owner);

    hub.governance.mitoTimelock.grantRole(hub.governance.mitoTimelock.PROPOSER_ROLE(), address(hub.governance.mito));
    hub.governance.mitoTimelock.grantRole(hub.governance.mitoTimelock.PROPOSER_ROLE(), govAdmin);

    hub.governance.mitoTimelock.grantRole(hub.governance.mitoTimelock.EXECUTOR_ROLE(), address(hub.governance.mito));
    hub.governance.mitoTimelock.grantRole(hub.governance.mitoTimelock.EXECUTOR_ROLE(), govAdmin);

    vm.stopBroadcast();
  }
}
