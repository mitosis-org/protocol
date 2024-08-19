// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';

import { ERC20Snapshots } from '../../src/twab/ERC20Snapshots.sol';

contract TokenTest is Test {
  ERC20Snapshots public token;

  function setUp() public {
    token = new ERC20Snapshots();
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
    // lastTwab + (lastBalance * duration) //
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
