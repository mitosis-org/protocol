// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { Toolkit } from '../util/Toolkit.sol';

import { LibString } from '@solady/utils/LibString.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibRedeemQueue } from '../../src/lib/LibRedeemQueue.sol';

contract LibRedeemQueueTest is Toolkit {
  using LibRedeemQueue for *;
  using LibString for *;
  using SafeCast for uint256;

  LibRedeemQueue.Queue internal q;

  function setUp() public { }

  function test_enqueue() public {
    for (uint256 i = 0; i < 3; i++) {
      _enqueue(makeAddr('recipient-1'), 1 ether, bytes('A'));
      _enqueue(makeAddr('recipient-2'), 1 ether, bytes('B'));
      _enqueue(makeAddr('recipient-3'), 1 ether, bytes('C'));
    }

    assertEq(q.totalPendingAmount(), 9 ether);
    assertEq(q.totalRequestAmount(), 9 ether);
    assertEq(q.totalReservedAmount(), 0);

    assertEq(q.size, 9);
    assertEq(q.indexes[makeAddr('recipient-1')].size, 3);
    assertEq(q.indexes[makeAddr('recipient-2')].size, 3);
    assertEq(q.indexes[makeAddr('recipient-3')].size, 3);
  }

  function test_reserve() public { }

  function test_claim() public { }

  function _enqueue(address recipient, uint256 amount, bytes memory metadata) private {
    uint48 createdAt = _now48();
    uint256 reqId = q.enqueue(recipient, amount, createdAt, metadata);

    assertEq(amount, reqId == 0 ? amount : q.data[reqId].accumulated - q.data[reqId - 1].accumulated);
    assertEq(recipient, q.data[reqId].recipient);
    assertEq(createdAt, q.data[reqId].createdAt);
    assertEq(0, q.data[reqId].claimedAt);
    assertEq(metadata, q.data[reqId].metadata);

    assertEq(q.indexes[recipient].data[q.indexes[recipient].size - 1], reqId);
  }

  function _reserve(address executor, uint256 amount, bytes memory metadata) private {
    uint48 reservedAt = _now48();
    uint256 logId = q.reserve(executor, amount, reservedAt, metadata);
  }
}
