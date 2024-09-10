// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { TWABRewardDistributor } from '../src/hub/reward/TWABRewardDistributor.sol';
import { MockERC20TWABSnapshots } from './mock/MockERC20TWABSnapshots.t.sol';

contract MyTest is Test {
  TWABRewardDistributor distributor;
  MockERC20TWABSnapshots token;

  function setUp() public {
    distributor = new TWABRewardDistributor(100);

    token = new MockERC20TWABSnapshots();
    token.initialize('Token', 'TKN');
  }

  function test_temp() public {
    address eolVault = makeAddr('eolVault');

    vm.warp(100);

    token.mint(address(this), 10 ether);
    token.mint(address(1), 90 ether);
    token.approve(address(distributor), 10 ether);

    vm.warp(200);

    bytes memory metadata = distributor.encodeMetadata(address(token), 200);
    distributor.handleReward(eolVault, address(token), 10 ether, metadata);

    vm.warp(300);

    bool claimable = distributor.claimable(address(this), eolVault, address(token), metadata);

    distributor.claim(eolVault, address(token), 200);

    console.log(token.balanceOf(address(distributor)));
    console.log(token.balanceOf(address(this)));

    vm.prank(address(1));
    distributor.claim(eolVault, address(token), 200);
    console.log(token.balanceOf(address(distributor))); // 0
    console.log(token.balanceOf(address(address(1)))); // 99000000000000000000
    console.log(token.balanceOf(address(this))); //        1000000000000000000
  }
}
