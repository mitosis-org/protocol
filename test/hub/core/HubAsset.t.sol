// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { IHubAsset } from '../../../src/interfaces/hub/core/IHubAsset.sol';

contract HubAssetTest is Test {
  HubAsset hubAsset;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');
  address immutable user1 = makeAddr('user1');
  address immutable user2 = makeAddr('user2');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);
    HubAsset hubAssetImpl = new HubAsset();

    hubAsset = HubAsset(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(hubAssetImpl), address(_proxyAdmin), abi.encodeCall(hubAsset.initialize, ('Token', 'TKN'))
          )
        )
      )
    );
  }

  function test_metadata() public view {
    assertEq(hubAsset.name(), 'Token');
    assertEq(hubAsset.symbol(), 'TKN');
    assertEq(hubAsset.decimals(), 18);
  }

  function test_mint() public {
    uint256 amount = 100 ether;
    hubAsset.mint(user1, amount);
    assertEq(hubAsset.totalSupply(), amount);
    assertEq(hubAsset.balanceOf(user1), amount);
  }

  function test_approve() public {
    uint256 amount = 100 ether;
    assertTrue(hubAsset.approve(user1, amount));
    assertEq(hubAsset.allowance(address(this), user1), amount);
  }

  function test_transfer() public {
    uint256 amount = 100 ether;

    hubAsset.mint(address(this), amount);

    assertTrue(hubAsset.transfer(user1, amount));
    assertEq(hubAsset.totalSupply(), amount);

    assertEq(hubAsset.balanceOf(address(this)), 0);
    assertEq(hubAsset.balanceOf(user1), amount);
  }

  function test_transferFrom() public {
    address from = user2;
    uint256 amount = 100 ether;

    hubAsset.mint(from, amount);

    vm.prank(from);
    hubAsset.approve(address(this), amount);

    assertTrue(hubAsset.transferFrom(from, user1, amount));
    assertEq(hubAsset.totalSupply(), amount);

    assertEq(hubAsset.allowance(from, address(this)), 0);

    assertEq(hubAsset.balanceOf(from), 0);
    assertEq(hubAsset.balanceOf(user1), amount);
  }

  function test_InfiniteApproveTransferFrom() public {
    address from = user2;
    uint256 amount = 100 ether;

    hubAsset.mint(from, amount);

    vm.prank(from);
    hubAsset.approve(address(this), type(uint256).max);

    assertTrue(hubAsset.transferFrom(from, user1, amount));
    assertEq(hubAsset.balanceOf(from), 0);
    assertEq(hubAsset.balanceOf(user1), amount);

    assertEq(hubAsset.allowance(from, address(this)), type(uint256).max);
    assertEq(hubAsset.totalSupply(), amount);
  }

  function test_transfer_ERC20InsufficientBalance() public {
    uint256 amount = 100 ether;

    hubAsset.mint(address(this), amount);

    vm.expectRevert();
    hubAsset.transfer(user1, amount + 1);
  }

  function test_transferFrom_ERC20InsufficientAllowance() public {
    address from = user2;
    uint256 amount = 100 ether;

    hubAsset.mint(from, amount);

    vm.prank(from);
    hubAsset.approve(address(this), amount - 1);

    vm.expectRevert();
    hubAsset.transferFrom(from, user1, amount);
  }

  function test_transferFrom_ERC20InsufficientBalance() public {
    address from = user2;
    uint256 amount = 100 ether;

    hubAsset.mint(from, amount - 1);

    vm.prank(from);
    hubAsset.approve(address(this), amount);

    vm.expectRevert();
    hubAsset.transferFrom(from, user1, amount);
  }
}
