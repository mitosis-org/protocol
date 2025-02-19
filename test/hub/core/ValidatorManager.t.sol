// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/core/EpochFeeder.sol';
import { ValidatorManager } from '../../../src/hub/core/ValidatorManager.sol';
import { IConsensusValidatorEntrypoint } from
  '../../../src/interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockConsensusValidatorEntrypoint {
  mapping(bytes4 => uint256) public calls;

  receive() external payable { }

  fallback() external payable {
    // allow every call
    calls[msg.sig]++;
  }
}

contract ValidatorManagerTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  uint256 epochInterval = 100;

  MockConsensusValidatorEntrypoint entrypoint;
  EpochFeeder epochFeeder;
  ValidatorManager manager;

  function setUp() public {
    entrypoint = new MockConsensusValidatorEntrypoint();
    address entrypointAddr = address(entrypoint);

    epochFeeder = EpochFeeder(
      _proxy(
        address(new EpochFeeder()), //
        abi.encodeCall(EpochFeeder.initialize, (owner, block.timestamp + epochInterval, epochInterval))
      )
    );
    manager = ValidatorManager(
      _proxy(
        address(new ValidatorManager()), //
        abi.encodeCall(ValidatorManager.initialize, (owner, epochFeeder, IConsensusValidatorEntrypoint(entrypointAddr)))
      )
    );
  }

  function test_init() public view {
    assertEq(manager.owner(), owner);
    assertEq(address(manager.epochFeeder()), address(epochFeeder));
    assertEq(address(manager.entrypoint()), address(entrypoint));
  }
}
