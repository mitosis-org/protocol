// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibRedeemQueue } from '../../src/lib/LibRedeemQueue.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract LibRedeemQueueTest is Toolkit {
  using LibRedeemQueue for *;
  using LibString for *;
  using SafeCast for uint256;

  LibRedeemQueue.Queue internal q;

  function setUp() public { }

  function test_enqueue(uint256 amountPerEnqueue) public {
    vm.assume(1 ether <= amountPerEnqueue && amountPerEnqueue < 1000 ether);

    for (uint256 i = 0; i < 3; i++) {
      _enqueue(makeAddr('recipient-1'), amountPerEnqueue, bytes('A'));
      _enqueue(makeAddr('recipient-2'), amountPerEnqueue, bytes('B'));
      _enqueue(makeAddr('recipient-3'), amountPerEnqueue, bytes('C'));
    }

    assertEq(q.totalPendingAmount(), amountPerEnqueue * 9);
    assertEq(q.totalRequestAmount(), amountPerEnqueue * 9);
    assertEq(q.totalReservedAmount(), 0);

    assertEq(q.size, 9);
    assertEq(q.indexes[makeAddr('recipient-1')].size, 3);
    assertEq(q.indexes[makeAddr('recipient-2')].size, 3);
    assertEq(q.indexes[makeAddr('recipient-3')].size, 3);
  }

  function test_reserve(uint256 amountPerReserve) public {
    vm.assume(1 ether <= amountPerReserve && amountPerReserve < 1000 ether);

    _reserve(makeAddr('strategist-1'), amountPerReserve, bytes('A'));
    _reserve(makeAddr('strategist-2'), amountPerReserve, bytes('B'));
    _reserve(makeAddr('strategist-3'), amountPerReserve, bytes('C'));
  }

  function test_claim(uint256 amountPerRequest) public {
    vm.assume(1 ether <= amountPerRequest && amountPerRequest < 1000 ether);

    test_enqueue(amountPerRequest);
    test_reserve(amountPerRequest * 3);
    vm.warp(block.timestamp + 1);

    // now all of requests should be claimable, because redeemPeriod is zero
    _assertClaimed(makeAddr('recipient-1'), amountPerRequest, amountPerRequest * 3, 3);
    _assertClaimed(makeAddr('recipient-2'), amountPerRequest, amountPerRequest * 3, 3);
    _assertClaimed(makeAddr('recipient-3'), amountPerRequest, amountPerRequest * 3, 3);
  }

  function _enqueue(address recipient, uint256 amount, bytes memory metadata) private returns (uint256) {
    uint48 createdAt = _now48();
    uint256 reqId = q.enqueue(recipient, amount, createdAt, metadata);

    assertEq(amount, reqId == 0 ? amount : q.data[reqId].accumulated - q.data[reqId - 1].accumulated);
    assertEq(recipient, q.data[reqId].recipient);
    assertEq(createdAt, q.data[reqId].createdAt);
    assertEq(0, q.data[reqId].claimedAt);
    assertEq(metadata, q.data[reqId].metadata);

    assertEq(q.indexes[recipient].data[q.indexes[recipient].size - 1], reqId);

    return reqId;
  }

  function _reserve(address executor, uint256 amount, bytes memory metadata) private returns (uint256) {
    uint48 reservedAt = _now48();
    uint256 logId = q.reserve(executor, amount, reservedAt, metadata);

    assertEq(
      amount, logId == 0 ? amount : q.reserveHistory[logId].accumulated - q.reserveHistory[logId - 1].accumulated
    );
    assertEq(reservedAt, q.reserveHistory[logId].reservedAt);
    assertEq(metadata, q.reserveHistory[logId].metadata);

    return logId;
  }

  function _claim(address recipient, uint256 maxClaimSize) private returns (uint256, uint256) {
    uint256 prevOffset = q.indexes[recipient].offset;
    uint256 totalClaimed = q.claim(recipient, maxClaimSize, _now48());
    return (totalClaimed, q.indexes[recipient].offset - prevOffset);
  }

  function _assertClaimed(
    address recipient,
    uint256 maxClaimSize,
    uint256 expectedTotalClaimed,
    uint256 expectedClaimedCount
  ) private {
    (uint256 totalClaimed, uint256 claimedCount) = _claim(recipient, maxClaimSize);
    assertEq(totalClaimed, expectedTotalClaimed);
    assertEq(claimedCount, expectedClaimedCount);
  }
}
