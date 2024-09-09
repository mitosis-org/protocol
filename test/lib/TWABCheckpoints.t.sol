// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import '../../src/lib/TWABCheckpoints.sol';

contract TWABCheckpointsTest is Test {
  using TWABCheckpoints for TWABCheckpoints.Trace;

  TWABCheckpoints.Trace private trace;

  function testPushAndLookup() public {
    (uint208 balance, uint256 accumulatedTWAB, uint48 position) = trace.latest();
    assertEq(balance, 0);
    assertEq(accumulatedTWAB, 0);
    trace.push(uint48(block.timestamp), 100, 1000);

    (balance, accumulatedTWAB, position) = trace.latest();
    assertEq(balance, 100);
    assertEq(accumulatedTWAB, 1000);

    trace.push(uint48(block.timestamp + 1), 200, 2000);

    (balance, accumulatedTWAB, position) = trace.latest();
    assertEq(balance, 200);
    assertEq(accumulatedTWAB, 2000);

    (balance, accumulatedTWAB, position) = trace.lowerLookup(uint48(block.timestamp));
    assertEq(balance, 100);
    assertEq(accumulatedTWAB, 1000);
  }

  function testLength() public {
    assertEq(trace.length(), 0);
    trace.push(uint48(block.timestamp), 100, 1000);
    assertEq(trace.length(), 1);
  }

  function testLatestCheckpoint() public {
    (bool exists, uint48 position, uint208 balance, uint256 accumulatedTWAB) = trace.latestCheckpoint();
    assertEq(exists, false);

    trace.push(uint48(block.timestamp), 100, 1000);
    (exists, position, balance, accumulatedTWAB) = trace.latestCheckpoint();
    assertEq(exists, true);
    assertEq(balance, 100);
    assertEq(accumulatedTWAB, 1000);
  }
}
