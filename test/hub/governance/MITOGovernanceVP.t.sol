// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MITOGovernanceVP } from '../../../src/hub/governance/MITOGovernanceVP.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MITOGovernanceVPTest is Toolkit {
  MockContract votingPowerToken1;
  MockContract votingPowerToken2;
  MITOGovernanceVP vp;

  function setUp() public { }
}
