// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { LibRedeemQueue } from '../../src/lib/LibRedeemQueue.sol';

struct DataSet {
  address recipient;
  uint256 amount;
}

struct RequestSet {
  uint256 itemIndex;
  LibRedeemQueue.Request request;
}

library LibDataSet {
  using LibRedeemQueue for *;

  function recipients(DataSet[] memory dataset) internal pure returns (address[] memory recipients_) {
    uint256 recipientCount = 0;
    address[] memory recipientsBuffer = new address[](dataset.length);
    for (uint256 i = 0; i < dataset.length; i++) {
      bool found = false;
      for (uint256 j = 0; j < recipientsBuffer.length; j++) {
        if (recipientsBuffer[j] != dataset[i].recipient) continue;
        found = true;
        break;
      }

      if (!found) {
        recipientsBuffer[recipientCount] = dataset[i].recipient;
        recipientCount++;
      }
    }

    recipients_ = new address[](recipientCount);
    for (uint256 i = 0; i < recipientCount; i++) {
      recipients_[i] = recipientsBuffer[i];
    }

    return recipients_;
  }

  function requests(DataSet[] memory dataset, LibRedeemQueue.Queue storage queue, address recipient)
    internal
    view
    returns (RequestSet[] memory requests_)
  {
    uint256 itemCount = 0;
    RequestSet[] memory requestsBuffer = new RequestSet[](dataset.length);
    for (uint256 i = 0; i < dataset.length; i++) {
      if (dataset[i].recipient != recipient) continue;

      requestsBuffer[itemCount] = RequestSet({ itemIndex: i, request: queue.get(i) });
      itemCount++;
    }

    requests_ = new RequestSet[](itemCount);
    for (uint256 i = 0; i < itemCount; i++) {
      requests_[i] = requestsBuffer[i];
    }

    return requests_;
  }
}

contract TestLibRedeemQueue is Test {
  using LibDataSet for *;
  using LibRedeemQueue for *;
  using LibString for *;

  LibRedeemQueue.Queue public queue;

  function setUp() public { }

  function _addr(string memory name) private pure returns (address) {
    return vm.addr(uint256(keccak256(bytes(name))));
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
    dataset[0] = DataSet({ recipient: _addr('recipient-1'), amount: 2 ether });
    dataset[1] = DataSet({ recipient: _addr('recipient-2'), amount: 4 ether });
    dataset[2] = DataSet({ recipient: _addr('recipient-1'), amount: 3 ether });
    dataset[3] = DataSet({ recipient: _addr('recipient-3'), amount: 6 ether });
    dataset[4] = DataSet({ recipient: _addr('recipient-1'), amount: 4 ether });
    dataset[5] = DataSet({ recipient: _addr('recipient-3'), amount: 7 ether });

    for (uint256 i = 0; i < dataset.length; i++) {
      queue.enqueue(dataset[i].recipient, dataset[i].amount);
    }

    return dataset;
  }

  function _reqToStr(LibRedeemQueue.Request memory req) private pure returns (string memory) {
    return string.concat(
      'Request(accumulated: ',
      req.accumulated.toString(),
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

    for (uint256 i = 0; i < queue.size; i++) {
      assertFalse(queue.get(i).isEmpty());
    }
  }

  function test_invariants_checkQueueSizeWithIndexes() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    uint256 totalItemsOfIndexes = 0;
    for (uint256 i = 0; i < recipients.length; i++) {
      totalItemsOfIndexes += queue.index(recipients[i]).size;
    }

    assertEq(queue.size, totalItemsOfIndexes);
  }

  function test_invariants_checkIndexSize() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      LibRedeemQueue.Index storage idx = queue.index(recipients[i]);
      for (uint256 j = 0; j < idx.size; j++) {
        assertFalse(queue.get(idx, j).isEmpty());
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

    LibRedeemQueue.Index storage index = queue.index(_addr('recipient-1'));

    vm.expectRevert(_errIndexOutOfRange(10, 0, 5));
    queue.get(10);

    vm.expectRevert(_errIndexOutOfRange(10, 0, 3));
    index.get(10);

    vm.expectRevert(_errIndexOutOfRange(10, 0, 3));
    queue.get(index, 10);
  }

  function test_index() public {
    _loadTestdata();

    address recipient = _addr('recipient-4');

    vm.expectRevert(_errEmptyIndex(recipient));
    queue.index(recipient);
  }

  function test_getClaimableRequests() public {
    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    LibRedeemQueue.Request memory lastItem = queue.get(queue.size - 1);

    for (uint256 i = 0; i < recipients.length; i++) {
      address recipient = recipients[i];
      RequestSet[] memory requests = dataset.requests(queue, recipient);
      uint256[] memory itemIndexes = new uint256[](requests.length);

      for (uint256 j = 0; j < requests.length; j++) {
        itemIndexes[j] = requests[j].itemIndex;
      }

      assertEq(itemIndexes, queue.getClaimableRequests(recipient, lastItem.accumulated));
    }
  }

  function test_searchQueueOffset() public {
    uint256 newOffset;
    bool found;

    _loadTestdata();

    for (uint256 i = 0; i < queue.size - 1; i++) {
      LibRedeemQueue.Request memory curr = queue.get(i);
      LibRedeemQueue.Request memory next = queue.get(i + 1);

      // update and get a new offset

      (newOffset, found) = queue.searchQueueOffset(curr.accumulated);
      assertEq(newOffset, i + 1);
      assertTrue(found);
      assertLe(queue.get(i).accumulated, next.accumulated - 1 ether);

      // update again, but not found

      (newOffset, found) = queue.searchQueueOffset(next.accumulated - 1 ether);
      assertEq(newOffset, i + 1);
      assertTrue(found);
      assertLe(queue.get(i).accumulated, next.accumulated - 1 ether);
    }
  }

  function test_searchIndexOffset() public {
    uint256 newOffset;
    bool found;

    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      address recipient = recipients[i];
      LibRedeemQueue.Index storage idx = queue.index(recipient);

      for (uint256 j = 0; j < idx.size - 1; j++) {
        LibRedeemQueue.Request memory curr = queue.get(idx, j);
        LibRedeemQueue.Request memory next = queue.get(idx, j + 1);

        // update and get a new offset

        (newOffset, found) = queue.searchIndexOffset(recipient, curr.accumulated);
        assertEq(newOffset, j + 1);
        assertTrue(found);
        assertLe(queue.get(idx, j).accumulated, curr.accumulated);

        // update again, but not found

        (newOffset, found) = queue.searchIndexOffset(recipient, next.accumulated - 1 ether);
        assertEq(newOffset, j + 1);
        assertTrue(found);
        assertLe(queue.get(idx, j).accumulated, next.accumulated - 1 ether);
      }
    }
  }

  function test_enqueue_diffRecipient() public {
    _test_enqueue(false);
  }

  function test_enqueue_sameRecipient() public {
    _test_enqueue(true);
  }

  function _test_enqueue(bool enqueueWithSameRecipient) internal {
    {
      address recipient = _addr('recipient-1');
      uint256 itemIdx = queue.enqueue(recipient, 1 ether);

      // check queue
      LibRedeemQueue.Request memory expected = LibRedeemQueue.Request({
        accumulated: 1 ether,
        recipient: recipient,
        createdAt: uint48(block.timestamp),
        claimedAt: 0
      });
      assertTrue(queue.get(itemIdx).eq(expected));

      // check index
      LibRedeemQueue.Index storage idx = queue.index(recipient);
      assertEq(idx.get(0), itemIdx);
      assertEq(idx.offset, 0);
    }

    vm.warp(block.timestamp + 10 seconds);

    {
      address recipient = enqueueWithSameRecipient ? _addr('recipient-1') : _addr('recipient-2');
      uint256 itemIdx = queue.enqueue(recipient, 4 ether);

      // check queue
      LibRedeemQueue.Request memory expected = LibRedeemQueue.Request({
        accumulated: 5 ether, // 1 ether + 4 ether
        recipient: recipient,
        createdAt: uint48(block.timestamp),
        claimedAt: 0
      });
      assertTrue(queue.get(itemIdx).eq(expected));

      // check index
      LibRedeemQueue.Index storage idx = queue.index(recipient);
      assertEq(idx.get(enqueueWithSameRecipient ? 1 : 0), itemIdx);
      assertEq(idx.offset, 0);
    }
  }

  function test_claim_queueSingle() public {
    _loadTestdata();

    vm.warp(block.timestamp + 10 seconds);

    vm.expectRevert(_errIndexOutOfRange(10, 0, 5));
    queue.claim(10);

    vm.expectRevert(_errNotReadyToClaim(0));
    queue.claim(0);

    queue.offset = 1;

    vm.expectRevert(_errNotReadyToClaim(1));
    queue.claim(1);

    queue.claim(0);
    queue.claim(0); // nothing happens

    LibRedeemQueue.Request memory item = queue.get(0);
    assertEq(item.claimedAt, uint48(block.timestamp));
    assertEq(item.createdAt + 10 seconds, item.claimedAt);
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
    queue.offset = 1;

    vm.expectRevert(_errNotReadyToClaim(1));
    queue.claim(itemIndexes);

    // resolve all - must success
    queue.offset = 5;

    queue.claim(itemIndexes);

    for (uint256 i = 0; i < itemIndexes.length; i++) {
      LibRedeemQueue.Request memory item = queue.get(itemIndexes[i]);
      assertEq(item.claimedAt, uint48(block.timestamp));
      assertEq(item.createdAt + 10 seconds, item.claimedAt);
    }
  }

  function test_claim_indexClaimDefaultLimit() public {
    _test_claim_index(LibRedeemQueue.DEFAULT_CLAIM_SIZE);
  }

  function test_claim_indexClaimCustomLimit() public {
    _test_claim_index(50);
  }

  function test_claim_full() public {
    address recipient = _addr('recipient');
    uint256 claimSize = 10;

    for (uint256 i = 0; i < claimSize; i++) {
      queue.enqueue(recipient, 1 ether);
    }
    queue.updateQueueOffset(claimSize * 1 ether);
    queue.claim(recipient, claimSize + 1);

    assertEq(queue.size, claimSize);
    assertEq(queue.offset, claimSize);
    assertEq(queue.index(recipient).size, claimSize);
    assertEq(queue.index(recipient).offset, claimSize);
  }

  function _test_claim_index(uint256 claimSize) internal {
    address recipient = _addr('recipient');

    for (uint256 i = 0; i < (claimSize * 2) + 1; i++) {
      queue.enqueue(recipient, 1 ether);
    }

    // resolve all
    queue.offset = queue.size;

    // default
    if (claimSize == LibRedeemQueue.DEFAULT_CLAIM_SIZE) queue.claim(recipient);
    else queue.claim(recipient, claimSize);

    for (uint256 i = 0; i < claimSize; i++) {
      assertTrue(queue.get(i).isClaimed(), string.concat('!', i.toString()));
    }

    assertFalse(queue.get(claimSize).isClaimed(), string.concat('!', claimSize.toString()));
    assertEq(queue.index(recipient).offset, claimSize);

    // claim again
    if (claimSize == LibRedeemQueue.DEFAULT_CLAIM_SIZE) queue.claim(recipient);
    else queue.claim(recipient, claimSize);

    for (uint256 i = claimSize; i < claimSize * 2; i++) {
      assertTrue(queue.get(i).isClaimed(), string.concat('!', i.toString()));
    }

    assertFalse(queue.get(claimSize * 2).isClaimed(), string.concat('!', claimSize.toString()));
    assertEq(queue.index(recipient).offset, claimSize * 2);
  }

  function test_updateQueueOffset() public {
    uint256 newOffset;
    bool found;

    _loadTestdata();

    for (uint256 i = 0; i < queue.size - 1; i++) {
      LibRedeemQueue.Request memory curr = queue.get(i);
      LibRedeemQueue.Request memory next = queue.get(i + 1);

      // update and get a new offset

      (newOffset, found) = queue.updateQueueOffset(curr.accumulated);
      assertEq(newOffset, i + 1);
      assertEq(queue.offset, newOffset);
      assertTrue(found);
      assertLe(queue.get(i).accumulated, curr.accumulated);

      // update again, but not found

      (newOffset, found) = queue.updateQueueOffset(next.accumulated - 1 ether);
      assertEq(newOffset, i + 1);
      assertEq(queue.offset, newOffset);
      assertFalse(found);
      assertLe(queue.get(i).accumulated, next.accumulated - 1 ether);
    }
  }

  function test_updateIndexOffset() public {
    uint256 newOffset;
    bool found;

    DataSet[] memory dataset = _loadTestdata();
    address[] memory recipients = dataset.recipients();

    for (uint256 i = 0; i < recipients.length; i++) {
      address recipient = recipients[i];
      LibRedeemQueue.Index storage idx = queue.index(recipient);

      for (uint256 j = 0; j < idx.size - 1; j++) {
        LibRedeemQueue.Request memory curr = queue.get(idx, j);
        LibRedeemQueue.Request memory next = queue.get(idx, j + 1);

        // update and get a new offset
        queue.updateQueueOffset(curr.accumulated);
        (newOffset, found) = queue.updateIndexOffset(recipient);
        assertEq(newOffset, j + 1);
        assertEq(idx.offset, newOffset);
        assertTrue(found);
        assertLe(queue.get(idx, j).accumulated, curr.accumulated);

        // update again, but not found
        queue.updateQueueOffset(next.accumulated - 1 ether);
        (newOffset, found) = queue.updateIndexOffset(recipient);
        assertEq(newOffset, j + 1);
        assertEq(idx.offset, newOffset);
        assertFalse(found);
        assertLe(queue.get(idx, j).accumulated, next.accumulated - 1 ether);
      }
    }
  }
}
