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

  uint48 twabPeriod = 7 days;
  uint256 rewardPrecision = 10 ** 18;

  function setUp() public {
    delegationRegistry = new MockDelegationRegistry(mitosis);

    _proxyAdmin = new ProxyAdmin(owner);
    TWABRewardDistributor twabRewardDistributorImpl = new TWABRewardDistributor(1 days);

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

  function test_claim_simple() public {
    vm.warp(0);
    vm.startPrank(owner);

    uint256 ownerAmount = 20 ether;
    uint256 userAmount = 80 ether;
    uint256 rewardAmount = 10 ether;

    eolVault.mint(owner, ownerAmount);
    eolVault.mint(address(1), userAmount);

    reward.mint(owner, rewardAmount);
    reward.approve(address(twabRewardDistributor), rewardAmount);

    vm.warp(6 days);
    twabRewardDistributor.handleReward(address(eolVault), address(reward), rewardAmount, bytes(''));
    assertEq(twabRewardDistributor.getFirstBatchTimestamp(address(eolVault), address(reward)), 7 days);
    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 6 days);

    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 0);

    // not finalized batch timestamp
    assertFalse(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 7 days));
    assertEq(twabRewardDistributor.claimableAmount(address(eolVault), owner, address(reward), 7 days), 0);
    assertEq(twabRewardDistributor.claim(address(eolVault), address(100), address(reward), 7 days), 0);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 0);
    assertTrue(reward.balanceOf(address(100)) == 0);

    // finalize the batch timestamp
    vm.warp(7 days);
    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 7 days);

    uint256 expectReward;

    expectReward = 10 ether / 100 * 20;
    assertTrue(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 7 days));
    assertEq(twabRewardDistributor.claimableAmount(address(eolVault), owner, address(reward), 7 days), expectReward);
    assertEq(twabRewardDistributor.claim(address(eolVault), address(100), address(reward), 7 days), expectReward);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 7 days);
    assertTrue(reward.balanceOf(address(100)) == expectReward);

    vm.stopPrank();

    vm.startPrank(address(1));

    expectReward = 10 ether / 100 * 80;
    assertTrue(twabRewardDistributor.claimable(address(eolVault), address(1), address(reward), 7 days));
    assertEq(
      twabRewardDistributor.claimableAmount(address(eolVault), address(1), address(reward), 7 days), expectReward
    );
    assertEq(twabRewardDistributor.claim(address(eolVault), address(200), address(reward), 7 days), expectReward);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 7 days);
    assertTrue(reward.balanceOf(address(200)) == expectReward);

    vm.stopPrank();
  }

  function test_claim_multiple_batches() public {
    vm.startPrank(owner);

    vm.warp(3 days);

    eolVault.mint(owner, 20 ether);
    eolVault.mint(address(1), 80 ether);

    reward.mint(owner, 60 ether);
    reward.approve(address(twabRewardDistributor), 60 ether);

    vm.warp(6 days);
    twabRewardDistributor.handleReward(address(eolVault), address(reward), 10 ether, bytes('')); // batchTimestamp: 7 days -> reward: 10 ether
    assertEq(twabRewardDistributor.getFirstBatchTimestamp(address(eolVault), address(reward)), 7 days);
    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 6 days);

    vm.warp(7 days);
    twabRewardDistributor.handleReward(address(eolVault), address(reward), 10 ether, bytes('')); // batchTimestamp: 8 days -> reward: 10 ether
    twabRewardDistributor.handleReward(address(eolVault), address(reward), 20 ether, bytes('')); // batchTimestamp: 8 days -> reward: 30 ether

    vm.warp(10 days - 1);
    twabRewardDistributor.handleReward(address(eolVault), address(reward), 5 ether, bytes('')); // batchTimestamp: 10 days -> reward: 5 ether
    twabRewardDistributor.handleReward(address(eolVault), address(reward), 15 ether, bytes('')); // batchTimestamp: 10 days -> reward: 20 ether

    assertFalse(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 6 days));
    assertTrue(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 7 days));
    assertTrue(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 8 days));
    assertFalse(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 9 days));
    assertFalse(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 10 days)); // note that it returns false when not finalized

    uint256 expectReward;

    expectReward = (10 ether + 30 ether) / 100 * 20;
    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 9 days);
    assertEq(
      twabRewardDistributor.claimableAmountUntil(address(eolVault), owner, address(reward), 10 days), expectReward
    );
    assertEq(twabRewardDistributor.claim(address(eolVault), address(100), address(reward), 10 days), expectReward);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 9 days);

    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 9 days);
    assertEq(twabRewardDistributor.claimableAmountUntil(address(eolVault), owner, address(reward), 10 days), 0);
    assertEq(twabRewardDistributor.claim(address(eolVault), address(100), address(reward), 10 days), 0);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 9 days);

    vm.warp(10 days);
    assertEq(twabRewardDistributor.getLastFinalizedBatchTimestamp(address(eolVault)), 10 days);
    assertTrue(twabRewardDistributor.claimable(address(eolVault), owner, address(reward), 10 days));

    expectReward = 20 ether / 100 * 20;
    assertEq(
      twabRewardDistributor.claimableAmountUntil(address(eolVault), owner, address(reward), 10 days), expectReward
    );
    assertEq(twabRewardDistributor.claim(address(eolVault), address(100), address(reward), 10 days), expectReward);
    assertEq(twabRewardDistributor.getLastClaimedBatchTimestamp(address(eolVault), owner, address(reward)), 10 days);

    vm.stopPrank();
  }
}
