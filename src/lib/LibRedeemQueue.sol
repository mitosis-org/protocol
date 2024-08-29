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

  struct ReserveLog {
    uint208 accumulated;
    uint48 reservedAt;
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
    uint256 totalReserved;
    uint256 totalClaimed;
    uint256 redeemPeriod;
    ReserveLog[] reserveHistory;
    mapping(uint256 index => Request item) data;
    mapping(address recipient => Index index) indexes;
  }

  uint256 constant DEFAULT_CLAIM_SIZE = 100;

  event Queued(address indexed recipient, uint256 requestIdx, uint256 amount);
  event Claimed(address indexed recipient, uint256 requestIdx);
  event Reserved(uint256 amount, uint256 historyIndex);
  event QueueOffsetUpdated(uint256 oldOffset, uint256 newOffset);
  event IndexOffsetUpdated(address indexed recipient, uint256 oldOffset, uint256 newOffset);

  error LibRedeemQueue__EmptyIndex(address recipient);
  error LibRedeemQueue__IndexOutOfRange(uint256 index, uint256 from, uint256 to);
  error LibRedeemQueue__NotReadyToClaim(uint256 index);
  error LibRedeemQueue__InvalidRequestAmount();
  error LibRedeemQueue__InvalidReserveAmount();

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

  function isReserved(Queue storage q, Request memory x) internal view returns (bool) {
    return x.accumulated <= q.totalReserved;
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

  function amount(Queue storage q, uint256 itemIndex) internal view returns (uint256) {
    uint256 accumulated = get(q, itemIndex).accumulated;
    uint256 prevAccumulated = itemIndex == 0 ? 0 : get(q, itemIndex - 1).accumulated;
    return accumulated - prevAccumulated;
  }

  function reservedAt(Queue storage q, uint256 itemIndex) internal view returns (uint256 reservedAt_, bool isReserved_) {
    Request memory req = get(q, itemIndex);
    if (!isReserved(q, req)) return (0, false);

    (ReserveLog memory log, bool found) = _searchReserveLogByAccumulated(q.reserveHistory, req.accumulated);
    if (!found) return (0, false);

    return (log.reservedAt, true);
  }

  function pending(Queue storage q) internal view returns (uint256) {
    uint256 totalRequested = q.size == 0 ? 0 : q.data[q.size - 1].accumulated;
    uint256 totalReserved = q.totalReserved;
    return totalRequested > totalReserved ? totalRequested - totalReserved : 0;
  }

  function index(Queue storage q, address recipient) internal view returns (Index storage idx) {
    idx = q.indexes[recipient];
    if (idx.size == 0) revert LibRedeemQueue__EmptyIndex(recipient);
    return idx;
  }

  function claimable(Queue storage q, address recipient, uint256 accumulated)
    internal
    view
    returns (uint256[] memory indexes)
  {
    Index storage idx = index(q, recipient);

    uint256 offset = idx.offset;
    (uint256 queueOffset,) = _searchQueueOffset(q, accumulated);
    (uint256 newOffset,) = _searchIndexOffset(idx, queueOffset);

    uint256 count = 0;
    for (uint256 i = offset; i < newOffset; i++) {
      Request memory req = q.data[idx.data[i]];
      if (isClaimed(req)) continue;
      count += 1;
    }

    indexes = new uint256[](count);
    for ((uint256 i, uint256 j) = (offset, 0); i < newOffset; i++) {
      uint256 itemIndex = idx.data[i];
      if (isClaimed(q.data[itemIndex])) continue;
      indexes[j++] = itemIndex;
    }

    return indexes;
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

  function searchReserveLogByAccumulated(Queue storage q, uint256 accumulated)
    internal
    view
    returns (ReserveLog memory log, bool found)
  {
    return _searchReserveLogByAccumulated(q.reserveHistory, accumulated);
  }

  function searchReserveLogByTimestamp(Queue storage q, uint256 timestamp)
    internal
    view
    returns (ReserveLog memory log, bool found)
  {
    return _searchReserveLogByTimestamp(q.reserveHistory, timestamp);
  }

  function enqueue(Queue storage q, address recipient, uint256 requestAmount_) internal returns (uint256 itemIndex) {
    if (requestAmount_ == 0) revert LibRedeemQueue__InvalidRequestAmount();
    bool isPrevItemExists = q.size > 0;
    itemIndex = q.size;

    // store request
    q.data[itemIndex] = Request({
      accumulated: isPrevItemExists ? q.data[itemIndex - 1].accumulated + requestAmount_ : requestAmount_,
      recipient: recipient,
      createdAt: uint48(block.timestamp),
      claimedAt: 0
    });
    q.size += 1;

    // submit index
    Index storage idx = q.indexes[recipient];
    idx.data[idx.size] = itemIndex;
    idx.size += 1;

    emit Queued(recipient, itemIndex, requestAmount_);

    return itemIndex;
  }

  function claim(Queue storage q, uint256 itemIndex) internal returns (uint256 claimed) {
    return _claim(q, itemIndex, true);
  }

  function claim(Queue storage q, uint256[] memory itemIndexes) internal returns (uint256 totalClaimed) {
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      totalClaimed += _claim(q, itemIndexes[i], false);
    }
    if (totalClaimed > 0) q.totalClaimed += totalClaimed;
    return totalClaimed;
  }

  function _claim(Queue storage q, uint256 itemIndex, bool applyToState) internal returns (uint256 claimed) {
    if (itemIndex >= q.size) revert LibRedeemQueue__IndexOutOfRange(itemIndex, 0, q.size - 1);
    if (itemIndex >= q.offset) revert LibRedeemQueue__NotReadyToClaim(itemIndex);
    Request memory req = q.data[itemIndex];
    if (!isClaimed(req)) {
      q.data[itemIndex].claimedAt = uint48(block.timestamp);
      // simplified version of calculating request amount
      claimed = itemIndex == 0 ? req.accumulated : req.accumulated - q.data[itemIndex - 1].accumulated;
      if (applyToState) q.totalClaimed += claimed;
    }
    emit Claimed(req.recipient, itemIndex);
    return claimed;
  }

  function claim(Queue storage q, address recipient) internal returns (uint256 totalClaimed) {
    return claim(q, recipient, DEFAULT_CLAIM_SIZE);
  }

  function claim(Queue storage q, address recipient, uint256 maxClaimSize) internal returns (uint256 totalClaimed) {
    _updateQueueOffset(q, q.totalReserved);

    Index storage idx = q.indexes[recipient];

    uint256 queueOffset = q.offset;
    uint256 idxOffset = idx.offset;
    uint256 i = idxOffset;
    for (; i < idx.size; i++) {
      if (i - idxOffset >= maxClaimSize) break;

      uint256 itemIndex = idx.data[i];
      Request memory req = q.data[itemIndex];
      if (isClaimed(req)) continue;
      if (itemIndex >= queueOffset) break;
      q.data[itemIndex].claimedAt = uint48(block.timestamp);
      // simplified version of calculating request amount
      totalClaimed += itemIndex == 0 ? req.accumulated : req.accumulated - q.data[itemIndex - 1].accumulated;

      emit Claimed(recipient, itemIndex);
    }

    // update index offset and total claimed if there's any claimed request
    if (totalClaimed > 0) {
      idx.offset = i;
      q.totalClaimed += totalClaimed;
    }
    return totalClaimed;
  }

  function reserve(Queue storage q, uint256 amount_) internal {
    if (amount_ == 0) revert LibRedeemQueue__InvalidReserveAmount();
    uint256 historyIndex = q.reserveHistory.length;

    q.totalReserved += amount_;
    q.reserveHistory.push(
      ReserveLog({
        accumulated: q.reserveHistory.length == 0
          ? uint208(amount_)
          : q.reserveHistory[historyIndex - 1].accumulated + uint208(amount_),
        reservedAt: uint48(block.timestamp)
      })
    );

    _updateQueueOffset(q, q.totalReserved);

    emit Reserved(amount_, historyIndex);
  }

  function update(Queue storage q) internal returns (uint256 offset, bool updated) {
    return _updateQueueOffset(q, q.totalReserved);
  }

  function _mid(uint256 low, uint256 high) private pure returns (uint256) {
    return (low & high) + (low ^ high) / 2; // avoid overflow
  }

  function _updateQueueOffset(Queue storage q, uint256 accumulated) private returns (uint256 offset, bool updated) {
    (offset, updated) = searchQueueOffset(q, accumulated);

    // assign
    if (updated) {
      uint256 oldOffset = q.offset;
      q.offset = offset;
      emit QueueOffsetUpdated(oldOffset, offset);
    }
    return (offset, updated);
  }

  function _updateIndexOffset(Queue storage q, address recipient) private returns (uint256 offset, bool updated) {
    Index storage idx = q.indexes[recipient];
    (offset, updated) = _searchIndexOffset(idx, q.offset);

    // assign
    if (updated) {
      uint256 oldOffset = idx.offset;
      idx.offset = offset;
      emit IndexOffsetUpdated(recipient, oldOffset, offset);
    }
    return (offset, updated);
  }

  function _searchQueueOffset(Queue storage q, uint256 accumulated) private view returns (uint256 offset, bool found) {
    offset = q.offset;

    uint256 low = offset;
    uint256 high = q.size;
    if (low == high) return (low, false);

    uint256 redeemPeriod = q.redeemPeriod;
    while (low < high) {
      uint256 mid = _mid(low, high);
      Request memory req = q.data[mid];
      if (req.accumulated <= accumulated && req.createdAt + redeemPeriod <= block.timestamp) low = mid + 1;
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
      uint256 mid = _mid(low, high);
      if (queueOffset > idx.data[mid]) low = mid + 1;
      else high = mid;
    }

    if (low == offset) return (low, false);
    return (low, true);
  }

  function _searchReserveLogByAccumulated(ReserveLog[] memory logs, uint256 accumulated)
    private
    pure
    returns (ReserveLog memory log, bool found)
  {
    uint256 low = 0;
    uint256 high = logs.length;
    if (low == high) return (log, false);

    // ensure accumulated is within the range of the logs
    if (accumulated < logs[low].accumulated || logs[high - 1].accumulated < accumulated) return (log, false);

    while (low < high) {
      uint256 mid = _mid(low, high);
      if (logs[mid].accumulated < accumulated) low = mid + 1;
      else high = mid;
    }

    return (logs[low], true);
  }

  function _searchReserveLogByTimestamp(ReserveLog[] memory logs, uint256 timestamp)
    private
    pure
    returns (ReserveLog memory log, bool found)
  {
    uint256 low = 0;
    uint256 high = logs.length;
    if (low == high) return (log, false);

    // ensure timestamp is within the range of the logs
    if (timestamp < logs[low].reservedAt || logs[high - 1].reservedAt < timestamp) return (log, false);

    while (low < high) {
      uint256 mid = _mid(low, high);
      if (logs[mid].reservedAt <= timestamp) low = mid + 1;
      else high = mid;
    }

    return (logs[low == 0 ? 0 : low - 1], true);
  }
}
