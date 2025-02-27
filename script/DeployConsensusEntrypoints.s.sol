// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { Script } from '@std/Script.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';

import { ConsensusValidatorEntrypoint } from '../src/hub/consensus-layer/ConsensusValidatorEntrypoint.sol';
import { ConsensusGovernanceEntrypoint } from '../src/hub/consensus-layer/ConsensusGovernanceEntrypoint.sol';

// NOTE: This is not for production use. This is just for testing and development purposes.
contract DeployConsensusEntrypoints is Script {
  function run() external {
    vm.startBroadcast();

    address owner = msg.sender;

    ConsensusValidatorEntrypoint val = ConsensusValidatorEntrypoint(
      payable(
        new ERC1967Proxy(
          address(new ConsensusValidatorEntrypoint()), abi.encodeCall(ConsensusValidatorEntrypoint.initialize, (owner))
        )
      )
    );
    ConsensusGovernanceEntrypoint gov = ConsensusGovernanceEntrypoint(
      payable(
        new ERC1967Proxy(
          address(new ConsensusGovernanceEntrypoint()),
          abi.encodeCall(ConsensusGovernanceEntrypoint.initialize, (owner))
        )
      )
    );

    val.setPermittedCaller(owner, true);
    gov.setPermittedCaller(owner, true);

    console.log('====================== Result ======================');
    console.log('Owner                        : ', address(owner));
    console.log('Permitted Caller             : ', address(owner));
    console.log('ConsensusValidatorEntrypoint : ', address(val));
    console.log('ConsensusGovernanceEntrypoint: ', address(gov));
    console.log('====================================================');

    vm.stopBroadcast();
  }
}
