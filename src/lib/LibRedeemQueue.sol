// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @dev LIFECYCLE:
 * 1. enqueue
 * 2. update queue offset
 * 3. update index offset
 * 3. claim (single, multiple, by recipient, by recipient with custom claim size)
 */
library LibRedeemQueue {
  struct Request {
    uint256 accumulated;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
  }

  struct Index {
    uint256 offset;
    uint256 size;
    mapping(uint256 index => uint256 itemIndex) data;
  }

  // INVARIANTS:
  /// QUEUE
  // * offset < size
  // * count(data) == size
  // * data[size - 1].accumulated is the total accumulated amount
  /// INDEX
  // * count(indexes[recipient]) == indexes[recipient].size
  // * sum(count(indexes[all_recipient])) == size
  struct Queue {
    uint256 offset;
    uint256 size;
    mapping(uint256 index => Request item) data;
    mapping(address recipient => Index index) indexes;
  }

  uint256 constant DEFAULT_CLAIM_SIZE = 100;

  error LibRedeemQueue__EmptyIndex(address recipient);
  error LibRedeemQueue__IndexOutOfRange(uint256 index, uint256 from, uint256 to);
  error LibRedeemQueue__NotReadyToClaim(uint256 index);

  function eq(Request memory x, Request memory y) internal pure returns (bool) {
    return x.accumulated == y.accumulated && x.recipient == y.recipient //
      && x.createdAt == y.createdAt && x.claimedAt == y.claimedAt;
  }

  function isEmpty(Request memory x) internal pure returns (bool) {
    return x.accumulated == 0 && x.recipient == address(0) && x.createdAt == 0 && x.claimedAt == 0;
  }

  function isClaimed(Request memory x) internal pure returns (bool) {
    return x.claimedAt != 0;
  }

  function get(Queue storage q, uint256 itemIndex) internal view returns (Request memory req) {
    if (itemIndex >= q.size) revert LibRedeemQueue__IndexOutOfRange(itemIndex, 0, q.size - 1);
    return q.data[itemIndex];
  }

  function get(Index storage idx, uint256 i) internal view returns (uint256 itemIndex) {
    if (i >= idx.size) revert LibRedeemQueue__IndexOutOfRange(i, 0, idx.size - 1);
    return idx.data[i];
  }

  function get(Queue storage q, Index storage idx, uint256 i) internal view returns (Request memory req) {
    return get(q, get(idx, i));
  }

  function index(Queue storage q, address recipient) internal view returns (Index storage idx) {
    idx = q.indexes[recipient];
    if (idx.size == 0) revert LibRedeemQueue__EmptyIndex(recipient);
    return idx;
  }

  function getClaimableRequests(Queue storage q, address recipient, uint256 accumulated)
    internal
    view
    returns (uint256[] memory itemIndexes)
  {
    Index storage idx = index(q, recipient);

    uint256 offset = idx.offset;
    (uint256 queueOffset,) = _searchQueueOffset(q, accumulated);
    (uint256 newOffset,) = _searchIndexOffset(idx, queueOffset);

    uint256 claimableRequestsCount = 0;
    for (uint256 i = offset; i < newOffset; i++) {
      if (isClaimed(q.data[idx.data[i]])) continue;
      claimableRequestsCount += 1;
    }

    itemIndexes = new uint256[](claimableRequestsCount);
    for ((uint256 i, uint256 j) = (offset, 0); i < newOffset; i++) {
      uint256 itemIndex = idx.data[i];
      if (isClaimed(q.data[itemIndex])) continue;
      itemIndexes[j++] = itemIndex;
    }

    return itemIndexes;
  }

  function searchQueueOffset(Queue storage q, uint256 accumulated) internal view returns (uint256 offset, bool found) {
    return _searchQueueOffset(q, accumulated);
  }

  function searchIndexOffset(Queue storage q, address recipient, uint256 accumulated)
    internal
    view
    returns (uint256 offset, bool found)
  {
    (uint256 queueOffset,) = _searchQueueOffset(q, accumulated);
    return _searchIndexOffset(q.indexes[recipient], queueOffset);
  }

  function enqueue(Queue storage q, address recipient, uint256 requestAmount) internal returns (uint256 itemIndex) {
    bool isPrevItemExists = q.size > 0;
    itemIndex = q.size;

    // store request
    q.data[itemIndex] = Request({
      accumulated: isPrevItemExists ? q.data[itemIndex - 1].accumulated + requestAmount : requestAmount,
      recipient: recipient,
      createdAt: uint48(block.timestamp),
      claimedAt: 0
    });
    q.size += 1;

    // submit index
    Index storage idx = q.indexes[recipient];
    idx.data[idx.size] = itemIndex;
    idx.size += 1;

    return itemIndex;
  }

  function claim(Queue storage q, uint256 itemIndex) internal {
    if (itemIndex >= q.size) revert LibRedeemQueue__IndexOutOfRange(itemIndex, 0, q.size - 1);
    if (itemIndex >= q.offset) revert LibRedeemQueue__NotReadyToClaim(itemIndex);
    if (!isClaimed(q.data[itemIndex])) q.data[itemIndex].claimedAt = uint48(block.timestamp);
  }

  function claim(Queue storage q, uint256[] memory itemIndexes) internal {
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      claim(q, itemIndexes[i]);
    }
  }

  function claim(Queue storage q, address recipient) internal {
    claim(q, recipient, DEFAULT_CLAIM_SIZE);
  }

  function claim(Queue storage q, address recipient, uint256 maxClaimSize) internal {
    Index storage idx = q.indexes[recipient];

    uint256 queueOffset = q.offset;
    uint256 idxOffset = idx.offset;
    uint256 i = idxOffset;
    for (; i < idx.size; i++) {
      if (i - idxOffset >= maxClaimSize) break;

      uint256 itemIndex = idx.data[i];
      if (isClaimed(q.data[itemIndex])) continue;
      if (itemIndex >= queueOffset) break;
      q.data[itemIndex].claimedAt = uint48(block.timestamp);
    }

    idx.offset = i;
  }

  function updateQueueOffset(Queue storage q, uint256 accumulated) internal returns (uint256 offset, bool updated) {
    (offset, updated) = searchQueueOffset(q, accumulated);

    // assign
    if (updated) q.offset = offset;
    return (offset, updated);
  }

  function updateIndexOffset(Queue storage q, address recipient) internal returns (uint256 offset, bool updated) {
    Index storage idx = q.indexes[recipient];
    (offset, updated) = _searchIndexOffset(idx, q.offset);

    // assign
    if (updated) idx.offset = offset;
    return (offset, updated);
  }

  function _searchQueueOffset(Queue storage q, uint256 accumulated) private view returns (uint256 offset, bool found) {
    offset = q.offset;

    uint256 low = offset;
    uint256 high = q.size;
    if (low == high) return (low, false);

    while (low < high) {
      uint256 mid = (low & high) + (low ^ high) / 2; // avoid overflow

      if (q.data[mid].accumulated <= accumulated) low = mid + 1;
      else high = mid;
    }

    if (low == offset) return (low, false);
    return (low, true);
  }

  function _searchIndexOffset(Index storage idx, uint256 queueOffset) private view returns (uint256 offset, bool found) {
    offset = idx.offset;

    uint256 low = offset;
    uint256 high = idx.size;
    if (low == high) return (low, false);

    while (low < high) {
      uint256 mid = (low & high) + (low ^ high) / 2; // avoid overflow

      if (queueOffset > idx.data[mid]) low = mid + 1;
      else high = mid;
    }

    if (low == offset) return (low, false);
    return (low, true);
  }
}
