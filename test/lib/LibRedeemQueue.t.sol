// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { LibRedeemQueue } from '../../src/lib/LibRedeemQueue.sol';
import { DataSet, RequestSet, LibDataSet } from '../util/queue/RedeemQueueDataSet.sol';
import { RedeemQueueWrapper } from '../util/queue/RedeemQueueWrapper.sol';

contract LibRedeemQueueTest is Test {
  using LibDataSet for *;
  using LibRedeemQueue for *;
  using LibString for *;

  RedeemQueueWrapper public queue;

  function setUp() public {
    queue = new RedeemQueueWrapper();
  }

  function _loadTestdata() private returns (DataSet[] memory dataset) {
    // SETUP TESTDATA
    // |-------------|-------------|-------------|
    // | recipient-1 | recipient-2 | recipient-3 |
    // |-------------|-------------|-------------|
    // | 2 ether (0) | 4 ether (1) | 6 ether (3) |
    // | 3 ether (2) |             | 7 ether (5) |
    // | 4 ether (4) |             |             |
    // |-------------|-------------|-------------|

    dataset = new DataSet[](6);
    dataset[0] = DataSet({ recipient: makeAddr('recipient-1'), shares: 2 ether, assets: 2 ether });
    dataset[1] = DataSet({ recipient: makeAddr('recipient-2'), shares: 4 ether, assets: 4 ether });
    dataset[2] = DataSet({ recipient: makeAddr('recipient-1'), shares: 3 ether, assets: 3 ether });
    dataset[3] = DataSet({ recipient: makeAddr('recipient-3'), shares: 6 ether, assets: 6 ether });
    dataset[4] = DataSet({ recipient: makeAddr('recipient-1'), shares: 4 ether, assets: 4 ether });
    dataset[5] = DataSet({ recipient: makeAddr('recipient-3'), shares: 7 ether, assets: 7 ether });

    for (uint256 i = 0; i < dataset.length; i++) {
      DataSet memory data = dataset[i];

      queue.enqueue(data.recipient, data.shares, data.assets);
      vm.warp(block.timestamp + 10 seconds);
    }

    return dataset;
  }

  function _reqToStr(LibRedeemQueue.Request memory req) private pure returns (string memory) {
    return string.concat(
      'Request(accumulatedAssets: ',
      req.accumulatedAssets.toString(),
      ', recipient: ',
      req.recipient.toHexString(),
      ', createdAt: ',
      uint256(req.createdAt).toString(),
      ', claimedAt: ',
      uint256(req.claimedAt).toString(),
      ')'
    );
  }

  function _errEmptyIndex(address recipient) private pure returns (bytes memory) {
    return abi.encodeWithSelector(LibRedeemQueue.LibRedeemQueue__EmptyIndex.selector, recipient);
  }

  function _errIndexOutOfRange(uint256 index, uint256 from, uint256 to) private pure returns (bytes memory) {
    return abi.encodeWithSelector(LibRedeemQueue.LibRedeemQueue__IndexOutOfRange.selector, index, from, to);
  }

  function _errNotReadyToClaim(uint256 index) private pure returns (bytes memory) {
    return abi.encodeWithSelector(LibRedeemQueue.LibRedeemQueue__NotReadyToClaim.selector, index);
  }

  // NOTE: INVARIANT TESTS

  function test_invariants_checkQueueSize() public {
    _loadTestdata();

    for (uint256 i = 0; i < queue.size(); i++) {
      assertFalse(queue.get(i).isEmpty());
    }
  }

  function test_invariants_checkQueueSizeWithIndexes() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    uint256 totalItemsOfIndexes = 0;
    for (uint256 i = 0; i < recipients.length; i++) {
      totalItemsOfIndexes += queue.size(recipients[i]);
    }

    assertEq(queue.size(), totalItemsOfIndexes);
  }

  function test_invariants_checkIndexSize() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      uint256 size = queue.size(recipients[i]);
      for (uint256 j = 0; j < size; j++) {
        assertFalse(queue.get(recipients[i], j).isEmpty());
      }
    }
  }

  // NOTE: UNIT TESTS

  function test_eq() public {
    _loadTestdata();

    LibRedeemQueue.Request memory x = queue.get(0);
    LibRedeemQueue.Request memory y = queue.get(0);
    LibRedeemQueue.Request memory z = queue.get(1);

    assertTrue(x.eq(y));
    assertFalse(x.eq(z));
  }

  function test_get() public {
    _loadTestdata();

    address recipient = makeAddr('recipient-1');

    vm.expectRevert(_errIndexOutOfRange(10, 0, 5));
    queue.get(10);

    vm.expectRevert(_errIndexOutOfRange(10, 0, 2));
    queue.get(recipient, 10);
  }

  function test_amount() public {
    DataSet[] memory dataset = _loadTestdata();

    for (uint256 i = 0; i < dataset.length; i++) {
      DataSet memory data = dataset[i];
      assertEq(queue.assets(i), data.assets);
      assertEq(queue.shares(i), data.shares);
    }
  }

  function test_reservedAt() public {
    DataSet[] memory dataset = _loadTestdata();

    uint256 startTime = block.timestamp + 1 seconds;

    for (uint256 i = 0; i < dataset.length; i++) {
      vm.warp(startTime + i * 10 seconds);
      queue.reserve(dataset[i].assets);

      (uint256 reservedAt, bool isReserved) = queue.reservedAt(i);
      assertEq(reservedAt, startTime + i * 10 seconds);
      assertTrue(isReserved);
    }
  }

  function test_pending() public {
    DataSet[] memory dataset = _loadTestdata();

    uint256 totalRequested = dataset.totalRequestedAssets();
    assertEq(queue.pending(), totalRequested);

    queue.reserve(totalRequested / 2);
    assertEq(queue.pending(), totalRequested / 2);

    queue.reserve(totalRequested / 2);
    assertEq(queue.pending(), 0);
  }

  function test_claimable() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    LibRedeemQueue.Request memory lastItem = queue.get(queue.size() - 1);

    for (uint256 i = 0; i < recipients.length; i++) {
      address recipient = recipients[i];
      RequestSet[] memory requests = dataset.requests(queue, recipient);
      uint256[] memory itemIndexes = new uint256[](requests.length);

      for (uint256 j = 0; j < requests.length; j++) {
        itemIndexes[j] = requests[j].itemIndex;
      }

      assertEq(itemIndexes, queue.claimable(recipient, lastItem.accumulatedAssets));
    }
  }

  function test_searchQueueOffset() public {
    uint256 newOffset;
    bool found;

    _loadTestdata();

    for (uint256 i = 0; i < queue.size() - 1; i++) {
      LibRedeemQueue.Request memory curr = queue.get(i);
      LibRedeemQueue.Request memory next = queue.get(i + 1);

      // update and get a new offset

      (newOffset, found) = queue.searchQueueOffset(curr.accumulatedAssets);
      assertEq(newOffset, i + 1);
      assertTrue(found);
      assertLe(queue.get(i).accumulatedAssets, next.accumulatedAssets - 1 ether);

      // update again, but not found

      (newOffset, found) = queue.searchQueueOffset(next.accumulatedAssets - 1 ether);
      assertEq(newOffset, i + 1);
      assertTrue(found);
      assertLe(queue.get(i).accumulatedAssets, next.accumulatedAssets - 1 ether);
    }
  }

  function test_searchQueueOffset_redeemPeriod() public {
    DataSet[] memory dataset = _loadTestdata();

    uint256 newOffset;
    bool updated;

    queue.setRedeemPeriod(10 seconds);

    vm.warp(1); // move to genesis
    queue.reserve(dataset.totalRequestedAssets()); // reserve all

    (newOffset, updated) = queue.update();
    assertEq(newOffset, 0);
    assertFalse(updated);

    for (uint256 i = 0; i < dataset.length; i++) {
      vm.warp(block.timestamp + 10 seconds);
      (newOffset, updated) = queue.update();
      assertEq(newOffset, i + 1);
      assertTrue(updated);
    }
  }

  function test_searchIndexOffset() public {
    uint256 newOffset;
    bool found;

    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      address recipient = recipients[i];

      for (uint256 j = 0; j < queue.size(recipient) - 1; j++) {
        LibRedeemQueue.Request memory curr = queue.get(recipient, j);
        LibRedeemQueue.Request memory next = queue.get(recipient, j + 1);

        // update and get a new offset

        (newOffset, found) = queue.searchIndexOffset(recipient, curr.accumulatedAssets);
        assertEq(newOffset, j + 1);
        assertTrue(found);
        assertLe(queue.get(recipient, j).accumulatedAssets, curr.accumulatedAssets);

        // update again, but not found

        (newOffset, found) = queue.searchIndexOffset(recipient, next.accumulatedAssets - 1 ether);
        assertEq(newOffset, j + 1);
        assertTrue(found);
        assertLe(queue.get(recipient, j).accumulatedAssets, next.accumulatedAssets - 1 ether);
      }
    }
  }

  function test_searchReserveLogByAccumulatedShares() public {
    uint256 startTime = block.timestamp;
    for (uint256 i = 0; i < 5; i++) {
      vm.warp(startTime + i * 10 seconds);
      queue.reserve(1 ether);
    }

    LibRedeemQueue.ReserveLog memory log;
    bool found;

    (log, found) = queue.searchReserveLogByAccumulatedShares(3 ether);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedShares, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedShares(2.5 ether);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedShares, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedShares(3.5 ether);
    assertEq(log.reservedAt, startTime + 30 seconds);
    assertEq(log.accumulatedShares, 4 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedShares(4 ether);
    assertEq(log.reservedAt, startTime + 30 seconds);
    assertEq(log.accumulatedShares, 4 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedShares(10 ether);
    assertFalse(found);
  }

  function test_searchReserveLogByAccumulatedAssets() public {
    uint256 startTime = block.timestamp;
    for (uint256 i = 0; i < 5; i++) {
      vm.warp(startTime + i * 10 seconds);
      queue.reserve(1 ether);
    }

    LibRedeemQueue.ReserveLog memory log;
    bool found;

    (log, found) = queue.searchReserveLogByAccumulatedAssets(3 ether);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedAssets, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedAssets(2.5 ether);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedAssets, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedAssets(3.5 ether);
    assertEq(log.reservedAt, startTime + 30 seconds);
    assertEq(log.accumulatedAssets, 4 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedAssets(4 ether);
    assertEq(log.reservedAt, startTime + 30 seconds);
    assertEq(log.accumulatedAssets, 4 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByAccumulatedAssets(10 ether);
    assertFalse(found);
  }

  function test_searchReserveLogByTimestamp() public {
    uint256 startTime = block.timestamp;
    for (uint256 i = 0; i < 5; i++) {
      vm.warp(startTime + i * 10 seconds);
      queue.reserve(1 ether);
    }

    LibRedeemQueue.ReserveLog memory log;
    bool found;

    (log, found) = queue.searchReserveLogByTimestamp(startTime + 15 seconds);
    assertEq(log.reservedAt, startTime + 10 seconds);
    assertEq(log.accumulatedAssets, 2 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByTimestamp(startTime + 20 seconds);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedAssets, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByTimestamp(startTime + 25 seconds);
    assertEq(log.reservedAt, startTime + 20 seconds);
    assertEq(log.accumulatedAssets, 3 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByTimestamp(startTime + 30 seconds);
    assertEq(log.reservedAt, startTime + 30 seconds);
    assertEq(log.accumulatedAssets, 4 ether);
    assertTrue(found);

    (log, found) = queue.searchReserveLogByTimestamp(startTime + 60 seconds);
    assertFalse(found);
  }

  function test_enqueue_diffRecipient() public {
    _test_enqueue(false);
  }

  function test_enqueue_sameRecipient() public {
    _test_enqueue(true);
  }

  function _test_enqueue(bool enqueueWithSameRecipient) internal {
    {
      address recipient = makeAddr('recipient-1');
      uint256 itemIdx = queue.enqueue(recipient, 1 ether, 1 ether);

      // check queue
      LibRedeemQueue.Request memory expected = LibRedeemQueue.Request({
        accumulatedShares: 1 ether,
        accumulatedAssets: 1 ether,
        recipient: recipient,
        createdAt: uint48(block.timestamp),
        claimedAt: 0
      });
      assertTrue(queue.get(itemIdx).eq(expected));

      // check index
      assertEq(queue.getIndexItemId(recipient, 0), itemIdx);
      assertEq(queue.offset(recipient), 0);
    }

    vm.warp(block.timestamp + 10 seconds);

    {
      address recipient = enqueueWithSameRecipient ? makeAddr('recipient-1') : makeAddr('recipient-2');
      uint256 itemIdx = queue.enqueue(recipient, 4 ether, 4 ether);

      // check queue
      LibRedeemQueue.Request memory expected = LibRedeemQueue.Request({
        accumulatedShares: 5 ether, // 1 ether + 4 ether
        accumulatedAssets: 5 ether, // 1 ether + 4 ether
        recipient: recipient,
        createdAt: uint48(block.timestamp),
        claimedAt: 0
      });
      assertTrue(queue.get(itemIdx).eq(expected));

      // check index
      assertEq(queue.getIndexItemId(recipient, enqueueWithSameRecipient ? 1 : 0), itemIdx);
      assertEq(queue.offset(recipient), 0);
    }
  }

  function test_claim_queueSingle() public {
    _loadTestdata();

    vm.warp(block.timestamp + 10 seconds);

    vm.expectRevert(_errIndexOutOfRange(10, 0, 5));
    queue.claim(10);

    vm.expectRevert(_errNotReadyToClaim(0));
    queue.claim(0);

    queue.reserve(2 ether);
    vm.warp(block.timestamp + 10 seconds);

    vm.expectRevert(_errNotReadyToClaim(1));
    queue.claim(1);

    queue.claim(0);
    queue.claim(0); // nothing happens

    LibRedeemQueue.Request memory item = queue.get(0);
    assertEq(item.claimedAt, uint48(block.timestamp));
    assertEq(item.createdAt + ((queue.size() + 2) * 10 seconds), item.claimedAt);
  }

  function test_claim_queueMulti() public {
    _loadTestdata();

    vm.warp(block.timestamp + 10 seconds);

    uint256[] memory itemIndexes = new uint256[](3);

    itemIndexes[0] = 10;
    itemIndexes[1] = 1;
    itemIndexes[2] = 4;

    vm.expectRevert(_errIndexOutOfRange(10, 0, 5));
    queue.claim(itemIndexes);

    itemIndexes[0] = 0;
    itemIndexes[1] = 1;
    itemIndexes[2] = 4;

    vm.expectRevert(_errNotReadyToClaim(0));
    queue.claim(itemIndexes);

    // resolve first - must reverted
    queue.reserve(2 ether);

    vm.expectRevert(_errNotReadyToClaim(1));
    queue.claim(itemIndexes);

    // resolve all - must success
    queue.reserve(26 ether);

    queue.claim(itemIndexes);

    for (uint256 i = 0; i < itemIndexes.length; i++) {
      LibRedeemQueue.Request memory item = queue.get(itemIndexes[i]);
      assertEq(item.claimedAt, uint48(block.timestamp));
      assertEq(item.createdAt + ((queue.size() - itemIndexes[i] + 1) * 10 seconds), item.claimedAt);
    }
  }

  function test_claim_indexClaimDefaultLimit() public {
    _test_claim_index(LibRedeemQueue.DEFAULT_CLAIM_SIZE);
  }

  function test_claim_indexClaimCustomLimit() public {
    _test_claim_index(50);
  }

  function test_claim_full() public {
    address recipient = makeAddr('recipient');
    uint256 claimSize = 10;

    for (uint256 i = 0; i < claimSize; i++) {
      queue.enqueue(recipient, 1 ether, 1 ether);
    }

    // resolve all
    queue.reserve(queue.size() * 1 ether);
    queue.claim(recipient, claimSize + 1);

    assertEq(queue.size(), claimSize);
    assertEq(queue.offset(), claimSize);
    assertEq(queue.size(recipient), claimSize);
    assertEq(queue.offset(recipient), claimSize);
  }

  function _test_claim_index(uint256 claimSize) internal {
    address recipient = makeAddr('recipient');

    for (uint256 i = 0; i < (claimSize * 2) + 1; i++) {
      queue.enqueue(recipient, 1 ether, 1 ether);
    }

    // resolve all
    queue.reserve(queue.size() * 1 ether);

    // default
    if (claimSize == LibRedeemQueue.DEFAULT_CLAIM_SIZE) queue.claim(recipient);
    else queue.claim(recipient, claimSize);

    for (uint256 i = 0; i < claimSize; i++) {
      assertTrue(queue.get(i).isClaimed(), string.concat('!', i.toString()));
    }

    assertFalse(queue.get(claimSize).isClaimed(), string.concat('!', claimSize.toString()));
    assertEq(queue.offset(recipient), claimSize);

    // claim again
    if (claimSize == LibRedeemQueue.DEFAULT_CLAIM_SIZE) queue.claim(recipient);
    else queue.claim(recipient, claimSize);

    for (uint256 i = claimSize; i < claimSize * 2; i++) {
      assertTrue(queue.get(i).isClaimed(), string.concat('!', i.toString()));
    }

    assertFalse(queue.get(claimSize * 2).isClaimed(), string.concat('!', claimSize.toString()));
    assertEq(queue.offset(recipient), claimSize * 2);
  }

  function test_reserve() public {
    _loadTestdata();

    for (uint256 i = 0; i < queue.size() - 1; i++) {
      LibRedeemQueue.Request memory curr = queue.get(i);
      LibRedeemQueue.Request memory next = queue.get(i + 1);

      // update and get a new offset

      vm.expectEmit();
      emit LibRedeemQueue.QueueOffsetUpdated(i, i + 1);

      queue.reserve(curr.accumulatedAssets - queue.totalReservedAssets());
      assertEq(queue.offset(), i + 1);
      assertLe(queue.get(i).accumulatedAssets, curr.accumulatedAssets);

      // update again, but not found

      queue.reserve(next.accumulatedAssets - 1 ether - queue.totalReservedAssets());
      assertEq(queue.offset(), i + 1);
      assertLe(queue.get(i).accumulatedAssets, next.accumulatedAssets - 1 ether);
    }
  }

  function test_updateIndexOffset() public {
    address[] memory recipients = _loadTestdata().recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      queue = new RedeemQueueWrapper();
      _loadTestdata();

      address recipient = recipients[i];

      for (uint256 j = 0; j < queue.size(recipient) - 1; j++) {
        LibRedeemQueue.Request memory curr = queue.get(recipient, j);
        LibRedeemQueue.Request memory next = queue.get(recipient, j + 1);

        // update and get a new offset
        queue.reserve(curr.accumulatedAssets - queue.totalReservedAssets());

        queue.claim(recipient);
        assertEq(queue.offset(recipient), j + 1);
        assertLe(queue.get(recipient, j).accumulatedAssets, curr.accumulatedAssets);

        // update again, but not found
        queue.reserve(next.accumulatedAssets - 1 ether - queue.totalReservedAssets());
        queue.claim(recipient);
        assertEq(queue.offset(recipient), j + 1);
        assertLe(queue.get(recipient, j).accumulatedAssets, next.accumulatedAssets - 1 ether);
      }
    }
  }

  // Add these tests to your TestLibRedeemQueue contract

  function test_enqueue_zeroAssets() public {
    vm.expectRevert(LibRedeemQueue.LibRedeemQueue__InvalidRequestAssets.selector);
    queue.enqueue(makeAddr('recipient'), 1 ether, 0);
  }

  function test_enqueue_zeroShares() public {
    vm.expectRevert(LibRedeemQueue.LibRedeemQueue__InvalidRequestShares.selector);
    queue.enqueue(makeAddr('recipient'), 0, 1 ether);
  }

  function test_reserve_zeroAmount() public {
    vm.expectRevert(LibRedeemQueue.LibRedeemQueue__InvalidReserveAmount.selector);
    queue.reserve(0);
  }

  function test_claim_outOfRange() public {
    _loadTestdata();
    uint256 invalidIndex = queue.size();

    vm.expectRevert(_errIndexOutOfRange(invalidIndex, 0, queue.size() - 1));
    queue.claim(invalidIndex);
  }

  function test_claim_notReadyToClaim() public {
    _loadTestdata();
    uint256 lastIndex = queue.size() - 1;

    vm.expectRevert(_errNotReadyToClaim(lastIndex));
    queue.claim(lastIndex);
  }

  function test_get_outOfRange() public {
    _loadTestdata();
    uint256 invalidIndex = queue.size();

    vm.expectRevert(_errIndexOutOfRange(invalidIndex, 0, queue.size() - 1));
    queue.get(invalidIndex);
  }

  function test_index_emptyIndex() public {
    address nonExistentRecipient = makeAddr('non-existent');

    vm.expectRevert(_errEmptyIndex(nonExistentRecipient));
    queue.getIndexItemId(nonExistentRecipient, 0);
  }

  function test_claimable_emptyIndex() public {
    address nonExistentRecipient = makeAddr('non-existent');

    vm.expectRevert(_errEmptyIndex(nonExistentRecipient));
    queue.claimable(nonExistentRecipient, 1 ether);
  }

  function test_reserve_overflow() public {
    _loadTestdata();
    uint256 maxUint256 = type(uint256).max;
    queue.reserve(1 ether); // Set initial reserve

    vm.expectRevert(); // This should revert due to overflow
    queue.reserve(maxUint256);
  }
}
