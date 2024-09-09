// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { TWABSnapshotsUtils } from '../../src/lib/TWABSnapshotsUtils.sol';
import { MockERC20TWABSnapshots } from '../mock/MockERC20TWABSnapshots.t.sol';

contract TWABSnapshotsUtilsTest is Test {
  using TWABSnapshotsUtils for *;

  address immutable accA = makeAddr('A');
  address immutable accB = makeAddr('B');

  MockERC20TWABSnapshots public token;

  function setUp() public {
    token = new MockERC20TWABSnapshots();
    token.initialize('Token', 'TKN');
  }

  function test() public {
    vm.warp(0);

    vm.startPrank(accA);
    token.mint(accA, 1000e18); // A: 1000, B: 0

    vm.warp(200);
    token.transfer(accB, 100e18); // A: 900, B: 100

    vm.warp(600);
    token.transfer(accB, 400e18); // A: 500, B: 500

    vm.warp(900);
    token.transfer(accB, token.balanceOf(accA)); // A: 0, B: 1000

    vm.warp(1000);

    uint256 accATWAB;
    uint256 accBTWAB;
    uint256 totalTWAB;

    // account TWAB should be calculated correctly
    accATWAB = token.getAccountTWABByTimestampRange(accA, 0, 800);
    accATWAB -= token.getAccountTWABByTimestampRange(accA, 0, 500);
    assertEq(accATWAB, token.getAccountTWABByTimestampRange(accA, 500, 800));

    // total TWAB should be calculated correctly
    totalTWAB = token.getTotalTWABByTimestampRange(0, 900);
    totalTWAB -= token.getTotalTWABByTimestampRange(0, 300);
    assertEq(totalTWAB, token.getTotalTWABByTimestampRange(300, 900));

    // total should be matched to accA + accB
    accATWAB = token.getAccountTWABByTimestampRange(accA, 300, 900);
    accBTWAB = token.getAccountTWABByTimestampRange(accB, 300, 900);
    totalTWAB = token.getTotalTWABByTimestampRange(300, 900);
    assertEq(accATWAB + accBTWAB, totalTWAB);

    vm.stopPrank();
  }
}
