// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { Merkle } from '@murky/Merkle.sol';

import { WETH } from '@solady/tokens/WETH.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MerkleRewardDistributor } from '../../../src/hub/reward/MerkleRewardDistributor.sol';
import { Treasury } from '../../../src/hub/reward/Treasury.sol';
import { IMerkleRewardDistributor } from '../../../src/interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { MockERC20Snapshots } from '../../mock/MockERC20Snapshots.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MerkleRewardDistributorTest is Toolkit {
  ProxyAdmin internal _proxyAdmin;
  Treasury _treasury;
  MerkleRewardDistributor internal _distributor;
  MockERC20Snapshots _token;

  address immutable owner = makeAddr('owner');
  address immutable matrixVault = makeAddr('matrixVault');
  address immutable rewarder = makeAddr('rewarder');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

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

    MerkleRewardDistributor distributorImpl = new MerkleRewardDistributor();
    _distributor = MerkleRewardDistributor(
      address(
        new TransparentUpgradeableProxy(
          address(distributorImpl),
          address(_proxyAdmin),
          abi.encodeCall(distributorImpl.initialize, (owner, address(_treasury)))
        )
      )
    );

    _token = new MockERC20Snapshots();
    _token.initialize('Token', 'TKN');

    bytes32 distributorManagerRole = _distributor.MANAGER_ROLE();

    bytes32 treasuryManagerRole = _treasury.TREASURY_MANAGER_ROLE();
    bytes32 dispatcherRole = _treasury.DISPATCHER_ROLE();

    vm.startPrank(owner);
    _distributor.grantRole(distributorManagerRole, owner);
    _treasury.grantRole(treasuryManagerRole, rewarder);
    _treasury.grantRole(dispatcherRole, address(_distributor));
    vm.stopPrank();
  }

  // function fetchRewards(uint256 stage, uint256 nonce, address matrixVault, address reward, uint256 amount)
  function test_fetchRewards() public {
    _token.mint(rewarder, 100 ether);

    vm.startPrank(rewarder);
    _token.approve(address(_treasury), 100 ether);
    _treasury.storeRewards(matrixVault, address(_token), 100 ether);
    vm.stopPrank();

    vm.prank(owner);
    _distributor.fetchRewards(0, 0, matrixVault, address(_token), 100 ether);

    assertEq(_token.balanceOf(address(_treasury)), 0);
    assertEq(_token.balanceOf(address(_distributor)), 100 ether);
  }
}
