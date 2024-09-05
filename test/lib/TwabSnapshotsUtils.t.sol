// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { ITwabSnapshots } from '../../src/interfaces/twab/ITwabSnapshots.sol';
import { TwabSnapshotsUtils } from '../../src/lib/TwabSnapshotsUtils.sol';
import { MockERC20TwabSnapshots } from '../mock/MockERC20TwabSnapshots.t.sol';

contract TwapSnapshotsUtilsTest is Test {
  using TwabSnapshotsUtils for *;

  address immutable accA = makeAddr('A');
  address immutable accB = makeAddr('B');

  MockERC20TwabSnapshots public token;

  function setUp() public {
    token = new MockERC20TwabSnapshots();
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

    uint256 accATwab;
    uint256 accBTwab;
    uint256 totalTwab;

    // account twab should be calculated correctly
    accATwab = token.getAccountTwabByTimestampRange(accA, 0, 800);
    accATwab -= token.getAccountTwabByTimestampRange(accA, 0, 500);
    assertEq(accATwab, token.getAccountTwabByTimestampRange(accA, 500, 800));

    // total twab should be calculated correctly
    totalTwab = token.getTotalTwabByTimestampRange(0, 900);
    totalTwab -= token.getTotalTwabByTimestampRange(0, 300);
    assertEq(totalTwab, token.getTotalTwabByTimestampRange(300, 900));

    // total should be matched to accA + accB
    accATwab = token.getAccountTwabByTimestampRange(accA, 300, 900);
    accBTwab = token.getAccountTwabByTimestampRange(accB, 300, 900);
    totalTwab = token.getTotalTwabByTimestampRange(300, 900);
    assertEq(accATwab + accBTwab, totalTwab);

    vm.stopPrank();
  }
}
