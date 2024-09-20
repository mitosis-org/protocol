// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { TWABRewardDistributor } from '../../../src/hub/reward/TWABRewardDistributor.sol';
import { IRewardConfigurator } from '../../../src/interfaces/hub/reward/IRewardConfigurator.sol';
import { TWABSnapshotsUtils } from '../../../src/lib/TWABSnapshotsUtils.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';
import { MockRewardConfigurator } from '../../mock/MockRewardConfigurator.t.sol';

contract TWABRewardDistributortTest is Test {
  TWABRewardDistributor twabRewardDistributor;
  MockRewardConfigurator rewardConfigurator;
  MockERC20TWABSnapshots token;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');

  function setUp() public {
    rewardConfigurator = new MockRewardConfigurator(10e8);

    _proxyAdmin = new ProxyAdmin(owner);
    TWABRewardDistributor twabRewardDistributorImpl = new TWABRewardDistributor();

    twabRewardDistributor = TWABRewardDistributor(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(twabRewardDistributorImpl),
            address(_proxyAdmin),
            abi.encodeCall(twabRewardDistributor.initialize, (owner, owner, address(rewardConfigurator), 100))
          )
        )
      )
    );

    token = new MockERC20TWABSnapshots();
    token.initialize('Token', 'TKN');
  }

  function test_simple_claim() public {
    address eolVault = makeAddr('eolVault');

    vm.warp(100);

    vm.startPrank(owner);

    uint256 ownerAmount = 10 ether;
    uint256 userAmount = 90 ether;

    token.mint(owner, ownerAmount);
    token.mint(address(1), userAmount);
    token.approve(address(twabRewardDistributor), ownerAmount);

    vm.warp(200);

    bytes memory metadata = twabRewardDistributor.encodeMetadata(address(token), 200);

    twabRewardDistributor.handleReward(eolVault, address(token), ownerAmount, metadata);

    vm.warp(300);

    twabRewardDistributor.claim(address(token), metadata);
    assertTrue(token.balanceOf(owner) == 10 ether / 100 * 10);

    vm.stopPrank();

    vm.prank(address(1));
    twabRewardDistributor.claim(address(token), metadata);
    assertTrue(token.balanceOf(address(1)) == 10 ether / 100 * 90 + userAmount);
  }
}
