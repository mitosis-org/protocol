// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { ERC20TwabSnapshots } from '../../src/twab/ERC20TwabSnapshots.sol';

contract TempERC20TwabSnapshots is ERC20TwabSnapshots {
  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20_init(name, symbol);
  }

  function mint(address account, uint256 value) external {
    _mint(account, value);
  }
}

contract TokenTest is Test {
  TempERC20TwabSnapshots public token;

  function setUp() public {
    token = new TempERC20TwabSnapshots();
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
