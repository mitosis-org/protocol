// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { GovMITO } from '../../src/hub/GovMITO.sol';
import { IGovMITO } from '../../src/interfaces/hub/IGovMITO.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract GovMITOTest is Test {
  GovMITO govMITO;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');
  address immutable minter = makeAddr('minter');
  address immutable user1 = makeAddr('user1');
  address immutable user2 = makeAddr('user2');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);
    GovMITO govMITOImpl = new GovMITO();

    govMITO = GovMITO(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(govMITOImpl),
            address(_proxyAdmin),
            abi.encodeCall(govMITO.initialize, (owner, 'Mitosis Governance Token', 'gMITO', minter))
          )
        )
      )
    );
  }

  function test_metadata() public view {
    assertEq(govMITO.name(), 'Mitosis Governance Token');
    assertEq(govMITO.symbol(), 'gMITO');
    assertEq(govMITO.decimals(), 18);
  }

  function test_minter() public view {
    assertEq(govMITO.minter(), minter);
  }

  function test_mint() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1, 100);
    assertEq(govMITO.balanceOf(user1), 100);
  }

  function test_mint_NotMinter() public {
    payable(user1).transfer(100);
    vm.prank(user1);
    vm.expectRevert(StdError.Unauthorized.selector);
    govMITO.mint{ value: 100 }(user1, 100);
  }

  function test_mint_MismatchedVaule() public {
    payable(minter).transfer(100000);

    vm.prank(minter);
    vm.expectRevert(abi.encodeWithSelector(StdError.InvalidParameter.selector, 'amount'));
    govMITO.mint{ value: 99 }(user1, 100);

    vm.prank(minter);
    vm.expectRevert(abi.encodeWithSelector(StdError.InvalidParameter.selector, 'amount'));
    govMITO.mint{ value: 101 }(user1, 100);
  }

  function test_redeem() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1, 100);

    vm.startPrank(user1);
    assertEq(user1.balance, 0);

    govMITO.redeem(user1, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 70);

    govMITO.redeem(user1, 70);
    assertEq(user1.balance, 100);
    assertEq(govMITO.balanceOf(user1), 0);

    vm.stopPrank();
  }

  function test_redeem_ERC20InsufficientBalance() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1, 100);

    vm.startPrank(user1);
    assertEq(user1.balance, 0);

    govMITO.redeem(user1, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.expectRevert();
    govMITO.redeem(user1, 71);

    vm.stopPrank();
  }

  function test_whiteListedSender() public {
    payable(minter).transfer(200);
    vm.startPrank(minter);
    govMITO.mint{ value: 100 }(user1, 100);
    assertEq(govMITO.balanceOf(user1), 100);
    assertEq(govMITO.balanceOf(user2), 0);
    vm.stopPrank();

    assertFalse(govMITO.isWhitelistedSender(user1));
    vm.prank(owner);
    govMITO.setWhitelistedSender(user1, true);
    assertTrue(govMITO.isWhitelistedSender(user1));

    vm.prank(user1);
    govMITO.transfer(user2, 30);
    assertEq(govMITO.balanceOf(user1), 70);
    assertEq(govMITO.balanceOf(user2), 30);

    vm.prank(user1);
    govMITO.approve(user2, 20);
    vm.prank(user2);
    govMITO.transferFrom(user1, user2, 20);
    assertEq(govMITO.balanceOf(user1), 50);
    assertEq(govMITO.balanceOf(user2), 50);
  }

  function test_whiteListedSender_NotWhitelisted() public {
    payable(minter).transfer(200);
    vm.startPrank(minter);
    govMITO.mint{ value: 100 }(user1, 100);
    assertEq(govMITO.balanceOf(user1), 100);
    assertEq(govMITO.balanceOf(user2), 0);
    vm.stopPrank();

    assertFalse(govMITO.isWhitelistedSender(user1));
    assertFalse(govMITO.isWhitelistedSender(user2));

    vm.prank(user1);
    vm.expectRevert(StdError.Unauthorized.selector);
    govMITO.transfer(user2, 30);

    vm.prank(user1);
    vm.expectRevert(StdError.Unauthorized.selector);
    govMITO.approve(user2, 20);

    vm.prank(owner);
    govMITO.setWhitelistedSender(user2, true);
    assertTrue(govMITO.isWhitelistedSender(user2));
    vm.prank(user2);
    vm.expectRevert(StdError.Unauthorized.selector);
    govMITO.transferFrom(user1, user2, 20); // user1 is not whitelisted. It is not important that user2 is whitelisted.
  }
}
