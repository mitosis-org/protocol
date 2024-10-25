// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { TWABRewardDistributor } from '../../../src/hub/reward/TWABRewardDistributor.sol';
import { TWABSnapshotsUtils } from '../../../src/lib/TWABSnapshotsUtils.sol';
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';

contract TWABRewardDistributortTest is Test {
  TWABRewardDistributor twabRewardDistributor;
  MockERC20TWABSnapshots eolVault;
  MockERC20TWABSnapshots reward;
  MockDelegationRegistry delegationRegistry;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  uint48 twabPeriod = 100;
  uint256 rewardPrecision = 10 ** 18;

  function setUp() public {
    delegationRegistry = new MockDelegationRegistry(mitosis);

    _proxyAdmin = new ProxyAdmin(owner);
    TWABRewardDistributor twabRewardDistributorImpl = new TWABRewardDistributor();

    twabRewardDistributor = TWABRewardDistributor(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(twabRewardDistributorImpl),
            address(_proxyAdmin),
            abi.encodeCall(twabRewardDistributor.initialize, (owner, twabPeriod, rewardPrecision))
          )
        )
      )
    );
    vm.startPrank(owner);
    twabRewardDistributor.grantRole(twabRewardDistributor.DISPATCHER_ROLE(), owner);
    vm.stopPrank();

    eolVault = new MockERC20TWABSnapshots();
    eolVault.initialize(address(delegationRegistry), 'EOL Vault', 'miAsset');

    reward = new MockERC20TWABSnapshots();
    reward.initialize(address(delegationRegistry), 'Reward Token', 'RTKN');
  }

  function test_simple_claim() public {
    vm.warp(100);

    vm.startPrank(owner);

    uint256 ownerAmount = 20 ether;
    uint256 rewardAmount = 10 ether;
    uint256 userAmount = 80 ether;

    eolVault.mint(owner, ownerAmount);
    eolVault.mint(address(1), userAmount);

    vm.warp(200);

    reward.mint(owner, rewardAmount);
    reward.approve(address(twabRewardDistributor), rewardAmount);
    twabRewardDistributor.handleReward(address(eolVault), address(reward), rewardAmount, bytes(''));

    // TODO(ray): add midnight roundup examples
    assertEq(twabRewardDistributor.getFirstBatchTimestamp(address(eolVault), address(reward)), 1 days);

    vm.warp(200 + 1 days);

    bytes memory metadata = twabRewardDistributor.encodeMetadata(1 days);

    uint256 prevBalance;
    uint256 expectReward;

    prevBalance = reward.balanceOf(owner);
    expectReward = 10 ether / 100 * 20;
    twabRewardDistributor.claim(address(eolVault), address(reward), metadata);
    assertTrue(reward.balanceOf(owner) == prevBalance + expectReward);

    vm.stopPrank();

    vm.startPrank(address(1));

    prevBalance = reward.balanceOf(address(1));
    expectReward = 10 ether / 100 * 80;

    twabRewardDistributor.claim(address(eolVault), address(reward), metadata);
    assertTrue(reward.balanceOf(address(1)) == prevBalance + expectReward);

    vm.stopPrank();
  }
}
