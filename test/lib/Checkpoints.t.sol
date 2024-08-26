// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';

import '../../../src/lib/TwabCheckpoints.sol';

contract TwabCheckpointsTest is Test {
  using TwabCheckpoints for TwabCheckpoints.Trace;

  TwabCheckpoints.Trace private trace;

  function testPushAndLookup() public {
    (uint208 balance, uint256 accumulatedTwab, uint48 position) = trace.latest();
    assertEq(balance, 0);
    assertEq(accumulatedTwab, 0);
    trace.push(uint48(block.timestamp), 100, 1000);

    (balance, accumulatedTwab, position) = trace.latest();
    assertEq(balance, 100);
    assertEq(accumulatedTwab, 1000);

    trace.push(uint48(block.timestamp + 1), 200, 2000);

    (balance, accumulatedTwab, position) = trace.latest();
    assertEq(balance, 200);
    assertEq(accumulatedTwab, 2000);

    (balance, accumulatedTwab, position) = trace.lowerLookup(uint48(block.timestamp));
    assertEq(balance, 100);
    assertEq(accumulatedTwab, 1000);
  }

  function testLength() public {
    assertEq(trace.length(), 0);
    trace.push(uint48(block.timestamp), 100, 1000);
    assertEq(trace.length(), 1);
  }

  function testLatestCheckpoint() public {
    (bool exists, uint48 position, uint208 balance, uint256 accumulatedTwab) = trace.latestCheckpoint();
    assertEq(exists, false);

    trace.push(uint48(block.timestamp), 100, 1000);
    (exists, position, balance, accumulatedTwab) = trace.latestCheckpoint();
    assertEq(exists, true);
    assertEq(balance, 100);
    assertEq(accumulatedTwab, 1000);
  }
}
