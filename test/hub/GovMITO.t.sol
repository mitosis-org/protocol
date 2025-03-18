// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { Vm } from '@std/Vm.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';

import { GovMITO } from '../../src/hub/GovMITO.sol';
import { IGovMITO } from '../../src/interfaces/hub/IGovMITO.sol';
import { StdError } from '../../src/lib/StdError.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract GovMITOTest is Toolkit {
  GovMITO govMITO;

  address immutable owner = makeAddr('owner');
  address immutable minter = makeAddr('minter');
  address immutable user1 = makeAddr('user1');
  address immutable user2 = makeAddr('user2');
  address immutable proxy = makeAddr('proxy');

  uint48 constant REDEEM_PERIOD = 21 days;

  function setUp() public {
    govMITO = GovMITO(
      payable(
        new ERC1967Proxy(address(new GovMITO()), abi.encodeCall(GovMITO.initialize, (owner, minter, REDEEM_PERIOD)))
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
    govMITO.mint{ value: 100 }(user1);
    assertEq(govMITO.balanceOf(user1), 100);
  }

  function test_mint_NotMinter() public {
    payable(user1).transfer(100);
    vm.prank(user1);
    vm.expectRevert(_errUnauthorized());
    govMITO.mint{ value: 100 }(user1);
  }

  function test_redeem_basic() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    vm.startPrank(user1);

    uint256 requestedAt = block.timestamp;
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD - 1);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 0);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 70);

    requestedAt = block.timestamp;
    govMITO.requestRedeem(user1, 70);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 0);

    vm.warp(requestedAt + REDEEM_PERIOD - 1);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 0);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 0);

    vm.warp(requestedAt + REDEEM_PERIOD);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 70);
    assertEq(user1.balance, 100);
    assertEq(govMITO.balanceOf(user1), 0);

    vm.stopPrank();
  }

  function test_redeem_requestTwiceAndClaimOnce() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    vm.startPrank(user1);

    uint256 requestedAt = block.timestamp;
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD / 2);
    govMITO.requestRedeem(user1, 50);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD / 2 + REDEEM_PERIOD);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 80);
    assertEq(user1.balance, 80);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.stopPrank();
  }

  function test_redeem_requestTwiceAndClaimTwice() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    vm.startPrank(user1);

    uint256 requestedAt = block.timestamp;
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD / 2);
    govMITO.requestRedeem(user1, 50);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD / 2 + REDEEM_PERIOD - 1);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 0);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD / 2 + REDEEM_PERIOD);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 50);
    assertEq(user1.balance, 80);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.stopPrank();
  }

  function test_redeem_requestAfterClaimable() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    vm.startPrank(user1);

    uint256 requestedAt = block.timestamp;
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD);
    govMITO.requestRedeem(user1, 50);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD * 2 - 1);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.warp(requestedAt + REDEEM_PERIOD * 2);
    claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 50);
    assertEq(user1.balance, 80);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.stopPrank();
  }

  function test_redeem_severalUsers() public {
    payable(minter).transfer(100);
    vm.startPrank(minter);
    govMITO.mint{ value: 50 }(user1);
    govMITO.mint{ value: 50 }(user2);
    vm.stopPrank();

    uint256 requestedAt = block.timestamp;

    vm.prank(user1);
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 20);

    vm.prank(user2);
    govMITO.requestRedeem(user2, 40);
    assertEq(user2.balance, 0);
    assertEq(govMITO.balanceOf(user2), 10);

    vm.warp(requestedAt + REDEEM_PERIOD);

    vm.prank(user1);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 30);
    assertEq(user1.balance, 30);
    assertEq(user2.balance, 0);
    assertEq(govMITO.balanceOf(user1), 20);
    assertEq(govMITO.balanceOf(user2), 10);

    vm.prank(user2);
    claimed = govMITO.claimRedeem(user2);
    assertEq(claimed, 40);
    assertEq(user1.balance, 30);
    assertEq(user2.balance, 40);
    assertEq(govMITO.balanceOf(user1), 20);
    assertEq(govMITO.balanceOf(user2), 10);
  }

  function test_redeem_differentReceiver() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    uint256 requestedAt = block.timestamp;
    vm.prank(user1);
    govMITO.requestRedeem(user2, 30);
    assertEq(user1.balance, 0);
    assertEq(user2.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD);
    vm.prank(user2);
    uint256 claimed = govMITO.claimRedeem(user2);
    assertEq(claimed, 30);
    assertEq(user1.balance, 0);
    assertEq(user2.balance, 30);
    assertEq(govMITO.balanceOf(user1), 70);
  }

  function test_redeem_anyoneCanClaim() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    uint256 requestedAt = block.timestamp;
    vm.prank(user1);
    govMITO.requestRedeem(user1, 30);
    assertEq(user1.balance, 0);
    assertEq(govMITO.balanceOf(user1), 70);

    vm.warp(requestedAt + REDEEM_PERIOD);
    vm.prank(user2);
    uint256 claimed = govMITO.claimRedeem(user1);
    assertEq(claimed, 30);
    assertEq(user1.balance, 30);
    assertEq(govMITO.balanceOf(user1), 70);
  }

  function test_redeem_ERC20InsufficientBalance() public {
    payable(minter).transfer(100);
    vm.prank(minter);
    govMITO.mint{ value: 100 }(user1);

    vm.startPrank(user1);

    govMITO.requestRedeem(user1, 30);

    vm.expectRevert();
    govMITO.requestRedeem(user1, 71);

    vm.stopPrank();
  }

  function test_whiteListedSender() public {
    payable(minter).transfer(200);
    vm.startPrank(minter);
    govMITO.mint{ value: 100 }(user1);
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

    assertFalse(govMITO.isWhitelistedSender(user2));
    vm.prank(owner);
    govMITO.setWhitelistedSender(user2, true);
    assertTrue(govMITO.isWhitelistedSender(user2));

    vm.prank(user2);
    govMITO.transferFrom(user1, user2, 20);
    assertEq(govMITO.balanceOf(user1), 50);
    assertEq(govMITO.balanceOf(user2), 50);
  }

  function test_whiteListedSender_NotWhitelisted() public {
    payable(minter).transfer(200);
    vm.startPrank(minter);
    govMITO.mint{ value: 100 }(user1);
    assertEq(govMITO.balanceOf(user1), 100);
    assertEq(govMITO.balanceOf(user2), 0);
    vm.stopPrank();

    assertFalse(govMITO.isWhitelistedSender(user1));
    assertFalse(govMITO.isWhitelistedSender(user2));

    vm.prank(user1);
    vm.expectRevert(_errUnauthorized());
    govMITO.transfer(user2, 30);

    vm.prank(user1);
    vm.expectRevert(_errUnauthorized());
    govMITO.approve(user2, 20);

    vm.prank(user1);
    vm.expectRevert(_errUnauthorized());
    govMITO.transferFrom(user1, user2, 20); // user1 is not whitelisted. It is not important that user2 is whitelisted
  }
}
