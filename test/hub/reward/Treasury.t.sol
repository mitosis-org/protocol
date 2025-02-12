// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { Treasury } from '../../../src/hub/reward/Treasury.sol';
import { MockERC20Snapshots } from '../../mock/MockERC20Snapshots.t.sol';
import { MockRewardDistributor } from '../../mock/MockRewardDistributor.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract TreasuryTest is Toolkit {
  ProxyAdmin _proxyAdmin;
  MockERC20Snapshots _token;
  Treasury _treasury;

  address owner = makeAddr('owner');
  address rewarder = makeAddr('rewarder');
  address matrixVault = makeAddr('matrixVault');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    _token = new MockERC20Snapshots();
    _token.initialize('Token', 'TKN');

    Treasury treasuryImpl = new Treasury();
    _treasury = Treasury(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(treasuryImpl), address(_proxyAdmin), abi.encodeCall(_treasury.initialize, (owner))
          )
        )
      )
    );

    vm.prank(owner);
    // _treasury.TREASURY_MANAGER_ROLE() ?
    _treasury.grantRole(0xede9dcdb0ce99dc7cec9c7be9246ad08b37853683ad91569c187b647ddf5e21c, rewarder);
  }

  function test_storeReward() public {
    _token.mint(rewarder, 100 ether);

    vm.startPrank(rewarder);
    _token.approve(address(_treasury), 100 ether);
    _treasury.storeRewards(matrixVault, address(_token), 100 ether);
    vm.stopPrank();

    assertEq(_token.balanceOf(address(_treasury)), 100 ether);
  }

  function test_dispatch() public {
    test_storeReward();
    // assertEq(_token.balanceOf(address(_treasury)), 100 ether);

    MockRewardDistributor distributor = new MockRewardDistributor();

    address dispatcher = makeAddr('dispatcher');
    vm.prank(owner);
    _treasury.grantRole(0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c, dispatcher);

    vm.prank(dispatcher);
    _treasury.dispatch(matrixVault, address(_token), 100 ether, address(distributor));

    assertEq(_token.balanceOf(address(_treasury)), 0);
    assertEq(_token.balanceOf(address(distributor)), 100 ether);
  }
}
