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
  address internal owner = makeAddr('owner');
  address internal govAdmin = makeAddr('govAdmin');

  string[] internal branchNames;

  function setUp() public override {
    super.setUp();
    branchNames.push('a');
    branchNames.push('b');
  }

  function test_init() public {
    EnvironmentT memory env = setUpEnv(owner, govAdmin, branchNames);

    backUpEnv(env);

    _printCreate3Contracts();
  }
}
