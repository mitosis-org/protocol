// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { MockDelegationRegistry } from '../mock/MockDelegationRegistry.t.sol';
import { MockERC20TWABSnapshots } from '../mock/MockERC20TWABSnapshots.t.sol';

contract ERC20SnapshotsTest is Test {
  MockDelegationRegistry public delegationRegistry;
  MockERC20TWABSnapshots public token;

  modifier trackGas(string memory op, string memory msg_) {
    uint256 startGas = gasleft();

    _;

    console.log('[%s] gas used: %d %s', op, startGas - gasleft(), msg_);
  }

  function setUp() public {
    delegationRegistry = new MockDelegationRegistry();
    token = new MockERC20TWABSnapshots();
    token.initialize(address(delegationRegistry), 'Token', 'TKN');
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

  function test_delegates() public {
    address alice = makeAddr('alice'); // self
    address bob = makeAddr('bob'); // default
    address carol = makeAddr('carol'); // registered

    vm.prank(bob);
    delegationRegistry.setDefaultDelegatee(makeAddr('bob-delegatee'));

    vm.prank(carol);
    token.delegate(makeAddr('carol-delegatee'));

    assertEq(token.delegates(alice), alice); // self
    assertEq(token.delegates(bob), makeAddr('bob-delegatee')); // default
    assertEq(token.delegates(carol), makeAddr('carol-delegatee')); // registered
  }

  function test_mint() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');

    uint256 value;
    uint256 twab;

    token.mint(alice, 100 ether);
    token.mint(bob, 100 ether);
    assertEq(token.totalSupply(), 200 ether);
    assertEq(token.balanceOf(alice), 100 ether);
    assertEq(token.balanceOf(bob), 100 ether);

    (value, twab,) = token.totalSupplySnapshot();
    assertEq(value, 200 ether);
    assertEq(twab, 0);

    (value,) = token.balanceSnapshot(alice);
    assertEq(value, 100 ether);

    (value, twab,) = token.delegateSnapshot(alice);
    assertEq(value, 100 ether);
    assertEq(twab, 0);
  }

  function test_transfer() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');

    token.mint(alice, 100 ether);
    token.mint(bob, 100 ether);

    vm.warp(block.timestamp + 1);
    vm.prank(alice);
    token.transfer(bob, 10 ether);

    uint48 past = _time() - 1;
    uint48 next = _time();

    _assertTotalSupplySnapshot(200 ether, 0, past);

    _assertBalanceSnapshot(alice, 90 ether, next);
    _assertDelegateSnapshot(alice, 90 ether, 100 ether, next); // 0 + (100 * 1)

    _assertBalanceSnapshot(bob, 110 ether, next);
    _assertDelegateSnapshot(bob, 110 ether, 100 ether, next); // 0 + (100 * 1)
  }

  function test_delegate() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');
    address carol = makeAddr('carol');

    token.mint(alice, 100 ether);
    token.mint(bob, 100 ether);

    vm.warp(block.timestamp + 1);
    vm.prank(alice);
    token.delegate(carol);

    uint48 past = _time() - 1;
    uint48 next = _time();

    _assertTotalSupplySnapshot(200 ether, 0, past);

    _assertBalanceSnapshot(alice, 100 ether, past); // balance snapshot will not be updated
    _assertDelegateSnapshot(alice, 0 ether, 100 ether, next); // 0 + (100 * 1)

    _assertBalanceSnapshot(bob, 100 ether, past);
    _assertDelegateSnapshot(bob, 100 ether, 0, past);

    _assertBalanceSnapshot(carol, 0 ether, 0); // nothing
    _assertDelegateSnapshot(carol, 100 ether, 0 ether, next);
  }

  function test_delegate_raw() public {
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');

    vm.expectEmit(address(token));
    emit IVotes.DelegateChanged(alice, alice, bob);

    vm.prank(alice);
    token.delegate(bob);
  }

  function test_AddSnapshots() public {
    address alice = makeAddr('alice');

    uint256 balance;
    uint256 twab;
    uint256 position;

    (balance, twab,) = token.delegateSnapshot(alice);
    assertEq(balance, 0);
    assertEq(twab, 0);

    vm.warp(block.timestamp + 1);
    token.mint(alice, 100 ether);

    (balance, twab, position) = token.delegateSnapshot(alice);
    assertEq(balance, 100 ether);
    assertEq(twab, 0);

    // // // // // // // // // // // // // //
    // lastTWAB + (lastBalance * duration) //
    // // // // // // // // // // // // // //

    vm.warp(block.timestamp + 100);
    token.mint(alice, 100 ether);

    (balance, twab,) = token.delegateSnapshot(alice);
    assertEq(balance, 200 ether);
    // 0 + ( 100 ether * 100)
    assertEq(twab, 100 ether * 100);

    vm.warp(block.timestamp + 500);
    token.mint(alice, 100 ether);
    (balance, twab, position) = token.delegateSnapshot(alice);
    assertEq(balance, 300 ether);
    assertEq(twab, (100 ether * 100) + (200 ether * 500));
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

  function _assertTotalSupplySnapshot(uint208 balance, uint256 twab, uint48 timestamp) internal view {
    uint256 balance_;
    uint256 twab_;
    uint48 timestamp_;

    (balance_, twab_, timestamp_) = token.totalSupplySnapshot();
    assertEq(balance_, balance);
    assertEq(twab_, twab);
    assertEq(timestamp_, timestamp);
  }

  function _assertBalanceSnapshot(address account, uint208 balance, uint48 timestamp) internal view {
    uint256 balance_;
    uint48 timestamp_;

    (balance_, timestamp_) = token.balanceSnapshot(account);
    assertEq(balance_, balance);
    assertEq(timestamp_, timestamp);
  }

  function _assertDelegateSnapshot(address account, uint208 balance, uint256 twab, uint48 timestamp) internal view {
    uint256 balance_;
    uint256 twab_;
    uint48 timestamp_;

    (balance_, twab_, timestamp_) = token.delegateSnapshot(account);
    assertEq(balance_, balance);
    assertEq(twab_, twab);
    assertEq(timestamp_, timestamp);
  }
}
