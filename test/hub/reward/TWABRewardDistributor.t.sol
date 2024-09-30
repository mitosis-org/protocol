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
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';
import { MockRewardConfigurator } from '../../mock/MockRewardConfigurator.t.sol';

contract TWABRewardDistributortTest is Test {
  TWABRewardDistributor twabRewardDistributor;
  MockRewardConfigurator rewardConfigurator;
  MockERC20TWABSnapshots token;
  MockDelegationRegistry delegationRegistry;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');

  uint48 twabPeriod = 100;

  function setUp() public {
    delegationRegistry = new MockDelegationRegistry();
    rewardConfigurator = new MockRewardConfigurator(10e8);

    _proxyAdmin = new ProxyAdmin(owner);
    TWABRewardDistributor twabRewardDistributorImpl = new TWABRewardDistributor();

    twabRewardDistributor = TWABRewardDistributor(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(twabRewardDistributorImpl),
            address(_proxyAdmin),
            abi.encodeCall(twabRewardDistributor.initialize, (owner, owner, address(rewardConfigurator), twabPeriod))
          )
        )
      )
    );

    token = new MockERC20TWABSnapshots();
    token.initialize(address(delegationRegistry), 'Token', 'TKN');
  }

  function test_simple_claim() public {
    address eolVault = makeAddr('eolVault');

    vm.warp(100);

    vm.startPrank(owner);

    uint256 ownerAmount = 10 ether;
    uint256 rewardAmount = 10 ether;
    uint256 userAmount = 80 ether;

    token.mint(owner, ownerAmount);
    token.mint(owner, rewardAmount);
    token.mint(address(1), userAmount);
    token.approve(address(twabRewardDistributor), ownerAmount);

    vm.warp(200);

    bytes memory metadata = twabRewardDistributor.encodeMetadata(address(token), 200);

    twabRewardDistributor.handleReward(eolVault, address(token), rewardAmount, metadata);

    // TODO(ray): add midnight roundup examples
    assertEq(twabRewardDistributor.getFirstBatchTimestamp(address(token), address(token)), 1 days);

    vm.warp(200 + 1 days);

    metadata = twabRewardDistributor.encodeMetadata(address(token), 1 days);

    uint256 prevBalance;
    uint256 expectReward;

    prevBalance = token.balanceOf(owner);
    expectReward = 10 ether / 100 * 10;
    twabRewardDistributor.claim(address(token), metadata);
    assertTrue(token.balanceOf(owner) == prevBalance + expectReward);

    vm.stopPrank();

    vm.startPrank(address(1));

    prevBalance = token.balanceOf(address(1));
    expectReward = 10 ether / 100 * 80;

    twabRewardDistributor.claim(address(token), metadata);
    assertTrue(token.balanceOf(address(1)) == prevBalance + expectReward);

    vm.stopPrank();
  }
}
