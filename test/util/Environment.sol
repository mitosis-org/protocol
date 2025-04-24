// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MockMailbox } from '@hpl/mock/MockMailbox.sol';
import { TestInterchainGasPaymaster } from '@hpl/test/TestInterchainGasPaymaster.sol';
import { TestIsm } from '@hpl/test/TestIsm.sol';

import { BranchConfigs } from '../util/types/BranchConfigs.sol';
import { BranchImplT } from '../util/types/BranchImplT.sol';
import { BranchProxyT } from '../util/types/BranchProxyT.sol';
import { HubConfigs } from '../util/types/HubConfigs.sol';
import { HubImplT } from '../util/types/HubImplT.sol';
import { HubProxyT } from '../util/types/HubProxyT.sol';
import { BranchDeployer } from './deployers/BranchDeployer.sol';
import { HubDeployer } from './deployers/HubDeployer.sol';
import './Functions.sol';

struct Hub {
  uint32 domain;
  MockMailbox mailbox;
  HubImplT.Chain impl;
  HubProxyT.Chain proxy;
}

struct Branch {
  string name;
  uint32 domain;
  MockMailbox mailbox;
  BranchImplT.Chain impl;
  BranchProxyT.Chain proxy;
}

abstract contract Environment is HubDeployer, BranchDeployer {
  using HubProxyT for HubProxyT.Chain;
  using HubImplT for HubImplT.Chain;
  using BranchProxyT for BranchProxyT.Chain;
  using BranchImplT for BranchImplT.Chain;

  struct EnvironmentT {
    Hub hub;
    Branch[] branches;
  }

  uint32 private _nextDomain = 12345;

  function setUpEnv(address owner, string[] memory branchNames) internal returns (EnvironmentT memory env) {
    // deploy all
    env.hub = _deployHub(owner);
    env.branches = new Branch[](branchNames.length);
    for (uint256 i = 0; i < branchNames.length; i++) {
      env.branches[i] = _deployBranch(owner, branchNames[i]);
    }

    // link mailboxes to each other
    MockMailbox[] memory mailboxes = _mailboxes(env);

    for (uint256 i = 0; i < mailboxes.length; i++) {
      for (uint256 j = i + 1; j < mailboxes.length; j++) {
        if (i == j) continue;
        mailboxes[i].addRemoteMailbox(mailboxes[j].localDomain(), mailboxes[j]);
        mailboxes[j].addRemoteMailbox(mailboxes[i].localDomain(), mailboxes[i]);
      }
    }
  }

  function backUpEnv(EnvironmentT memory env) internal {
    for (uint256 i = 0; i < env.branches.length; i++) {
      env.branches[i].impl.write(BranchImplT.stdPath(env.branches[i].name));
      env.branches[i].proxy.write(BranchProxyT.stdPath(env.branches[i].name));
    }

    env.hub.impl.write(HubImplT.stdPath());
    env.hub.proxy.write(HubProxyT.stdPath());
  }

  function _setUpMailbox() private returns (uint32, MockMailbox) {
    uint32 domain = _nextDomain++;

    MockMailbox mailbox = new MockMailbox(domain);

    mailbox.setDefaultIsm(address(new TestIsm()));
    mailbox.setDefaultHook(address(new TestInterchainGasPaymaster()));

    return (domain, mailbox);
  }

  function _deployHub(address owner) private returns (Hub memory hub) {
    (hub.domain, hub.mailbox) = _setUpMailbox();
    (hub.impl, hub.proxy) = deployHub(
      address(hub.mailbox), //
      owner,
      HubConfigs.read(_deployConfigPath('hub'))
    );
  }

  function _deployBranch(address owner, string memory name) private returns (Branch memory branch) {
    (branch.domain, branch.mailbox) = _setUpMailbox();
    (branch.impl, branch.proxy) = deployBranch(
      name, //
      address(branch.mailbox),
      owner,
      BranchConfigs.read(_deployConfigPath(name))
    );
  }

  function _mailboxes(EnvironmentT memory env) private returns (MockMailbox[] memory) {
    MockMailbox[] memory mailboxes = new MockMailbox[](env.branches.length + 1);
    mailboxes[0] = env.hub.mailbox;
    for (uint256 i = 1; i < env.branches.length; i++) {
      mailboxes[i] = env.branches[i].mailbox;
    }
  }

  function _deployConfigPath(string memory chain) private pure returns (string memory) {
    return cat('./test/testdata/deploy-', chain, '.config.json');
  }
}
