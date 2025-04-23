// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Environment } from '../util/Environment.sol';
import '../util/Functions.sol';
import { BranchConfigs } from '../util/types/BranchConfigs.sol';
import { BranchImplT } from '../util/types/BranchImplT.sol';
import { BranchProxyT } from '../util/types/BranchProxyT.sol';
import { HubConfigs } from '../util/types/HubConfigs.sol';
import { HubImplT } from '../util/types/HubImplT.sol';
import { HubProxyT } from '../util/types/HubProxyT.sol';

contract IntegrationTest is Environment {
  using HubProxyT for HubProxyT.Chain;
  using HubImplT for HubImplT.Chain;

  using BranchProxyT for BranchProxyT.Chain;
  using BranchImplT for BranchImplT.Chain;

  address internal owner = makeAddr('owner');

  struct Hub {
    uint32 domain;
    HubImplT.Chain impl;
    HubProxyT.Chain proxy;
  }

  struct Branch {
    string name;
    uint32 domain;
    BranchImplT.Chain impl;
    BranchProxyT.Chain proxy;
  }

  function test_init() public {
    Hub memory hub = _deployHub();
    Branch[] memory branches = new Branch[](2);
    branches[0] = _deployBranch('branch-a');
    branches[1] = _deployBranch('branch-b');

    hub.impl.write(HubImplT.stdPath());
    hub.proxy.write(HubProxyT.stdPath());

    branches[0].impl.write(BranchImplT.stdPath('branch-a'));
    branches[0].proxy.write(BranchProxyT.stdPath('branch-a'));

    branches[1].impl.write(BranchImplT.stdPath('branch-b'));
    branches[1].proxy.write(BranchProxyT.stdPath('branch-b'));

    _printCreate3Contracts();
  }

  function _deployHub() internal returns (Hub memory hub) {
    hub.domain = addDomain();
    (hub.impl, hub.proxy) = deployHub(
      address(mailbox(hub.domain)), //
      owner,
      HubConfigs.read(_deployConfigPath('hub'))
    );
  }

  function _deployBranch(string memory name) internal returns (Branch memory branch) {
    branch.domain = addDomain();
    (branch.impl, branch.proxy) = deployBranch(
      name, //
      address(mailbox(branch.domain)),
      owner,
      BranchConfigs.read(_deployConfigPath(name))
    );
  }

  function _deployConfigPath(string memory chain) private pure returns (string memory) {
    return cat('./test/testdata/deploy-', chain, '.config.json');
  }
}
