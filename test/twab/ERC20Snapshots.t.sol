// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { MockERC20Snapshots } from '../mock/MockERC20Snapshots.t.sol';

contract ERC20SnapshotsTest is Test {
  MockERC20Snapshots public token;

  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  modifier trackGas(string memory op, string memory msg_) {
    uint256 startGas = gasleft();

    _;

    console.log('[%s] gas used: %d %s', op, startGas - gasleft(), msg_);
  }

  function setUp() public {
    token = new MockERC20Snapshots();
    token.initialize('Token', 'TKN');
  }

  function test_gas() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');
    address carol = makeAddr('carol');

    _mint(alice, 100, '(100 -> alice) // very first transfer with contract storage initialization');
    _mint(bob, 100, '(100 -> bob) // mint to bob with narrow storage initialization');

    console.log('alice -> carol // transfer to user with non storage initialization');
    _transfer(alice, carol, 10, '');
    _transfer(carol, alice, 10, '');

    console.log('alice <-> bob // transfer each other');
    for (uint256 i = 0; i < 5; i++) {
      _transfer(alice, bob, 1, '');
      _transfer(bob, alice, 1, '');
    }

    console.log('alice <-> bob (max) // transfer to zero and recover');
    for (uint256 i = 0; i < 5; i++) {
      _transfer(alice, bob, 100, '');
      _transfer(bob, alice, 100, '');
    }
  }

  function test_mint() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');

    token.mint(alice, 100 ether);
    token.mint(bob, 100 ether);
    assertEq(token.totalSupply(), 200 ether);
    assertEq(token.balanceOf(alice), 100 ether);
    assertEq(token.balanceOf(bob), 100 ether);

    _assertTotalSupplySnapshot(200 ether);

    _assertBalanceSnapshot(alice, 100 ether);
  }

  function test_transfer() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');

    token.mint(alice, 100 ether);
    token.mint(bob, 100 ether);

    vm.warp(block.timestamp + 1);
    vm.prank(alice);
    token.transfer(bob, 10 ether);

    _assertTotalSupplySnapshot(200 ether);

    _assertBalanceSnapshot(alice, 90 ether);
    _assertBalanceSnapshot(bob, 110 ether);
  }

  function _mint(address account, uint256 value, string memory msg_) internal trackGas('mint', msg_) {
    token.mint(account, value);
  }

  function _transfer(address from, address to, uint256 value, string memory msg_) internal trackGas('transfer', msg_) {
    vm.prank(from);
    token.transfer(to, value);
  }

  function _time() internal view returns (uint48) {
    return Time.timestamp();
  }

  function _assertTotalSupplySnapshot(uint208 balance) internal view {
    assertEq(balance, token.totalSupplySnapshot(_time()));
  }

  function _assertBalanceSnapshot(address account, uint208 balance) internal view {
    assertEq(balance, token.balanceSnapshot(account, _time()));
  }
}
