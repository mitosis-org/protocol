// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { MockERC20TWABSnapshots } from '../mock/MockERC20TWABSnapshots.t.sol';

contract ERC20SnapshotsTest is Test {
  MockERC20TWABSnapshots public token;

  function setUp() public {
    token = new MockERC20TWABSnapshots();
    token.initialize('Token', 'TKN');
  }

  function test_AddSnapshots() public {
    uint256 balance;
    uint256 twab;
    uint256 position;

    (balance, twab,) = token.getLatestSnapshot(msg.sender);
    assertEq(balance, 0);
    assertEq(twab, 0);

    vm.warp(block.timestamp + 1);
    token.mint(msg.sender, 100 ether);

    (balance, twab, position) = token.getLatestSnapshot(msg.sender);
    assertEq(balance, 100 ether);
    assertEq(twab, 0);

    // // // // // // // // // // // // // //
    // lastTWAB + (lastBalance * duration) //
    // // // // // // // // // // // // // //

    vm.warp(block.timestamp + 100);
    token.mint(msg.sender, 100 ether);

    (balance, twab,) = token.getLatestSnapshot(msg.sender);
    assertEq(balance, 200 ether);
    // 0 + ( 100 ether * 100)
    assertEq(twab, 100 ether * 100);

    vm.warp(block.timestamp + 500);
    token.mint(msg.sender, 100 ether);
    (balance, twab, position) = token.getLatestSnapshot(msg.sender);
    assertEq(balance, 300 ether);
    assertEq(twab, (100 ether * 100) + (200 ether * 500));
  }
}
