// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';

import { CheckpointsExt } from './CheckpointsExt.sol';

/**
 * @dev LIFECYCLE:
 * 1. enqueue
 * 2. update queue offset
 * 3. update index offset
 * 3. claim (single, multiple, by recipient, by recipient with custom claim size)
 */
library LibRedeemQueue {
  using SafeCast for uint256;
  using Checkpoints for Checkpoints.Trace208;
  using CheckpointsExt for Checkpoints.Trace208;

  // ================================= SimpleOffsetQueue ================================= //

  error LibRedeemQueue__NothingToClaim();

  struct SimpleOffsetQueue {
    uint32 _offset;
    // storage reserve for future usage
    uint224 _reserved;
    Checkpoints.Trace208 _items;
  }

  function size(SimpleOffsetQueue storage $) internal view returns (uint256) {
    return $._items.length();
  }

  function offset(SimpleOffsetQueue storage $) internal view returns (uint256) {
    return $._offset;
  }

  function itemAt(SimpleOffsetQueue storage $, uint32 pos) internal view returns (uint48, uint208) {
    Checkpoints.Checkpoint208 memory checkpoint = $._items.at(pos);
    return (checkpoint._key, checkpoint._value);
  }

  function recentItemAt(SimpleOffsetQueue storage $, uint48 time) internal view returns (uint48, uint208) {
    Checkpoints.Trace208 storage items = $._items;
    uint256 pos = items.upperBinaryLookup(time, 0, items.length());
    if (pos == 0) return (0, 0);

    Checkpoints.Checkpoint208 memory checkpoint = $._items.at((pos - 1).toUint32());
    return (checkpoint._key, checkpoint._value);
  }

  function pending(SimpleOffsetQueue storage $, uint48 time) internal view returns (uint256, uint256) {
    Checkpoints.Trace208 storage items = $._items;

    uint32 offset_ = $._offset;
    uint256 reqLen = items.length();
    if (reqLen <= offset_) return (0, 0);

    uint256 total = items.latest() - items.valueAt(offset_);
    uint256 found = items.upperBinaryLookup(time, offset_, reqLen);
    if (offset_ == found) return (total, 0);

    uint256 available = items.valueAt((found - 1).toUint32()) - items.valueAt(offset_);
    return (total, available);
  }

  function append(SimpleOffsetQueue storage $, uint48 time, uint208 amount) internal returns (uint256) {
    Checkpoints.Trace208 storage items = $._items;

    uint256 reqId = items.length();

    if (reqId == 0) {
      items.push(0, 0);
      items.push(time, amount);
      reqId = 1;
    } else {
      items.push(time, items.latest() + amount);
    }

    return reqId;
  }

  function solve(SimpleOffsetQueue storage $, uint48 timestamp) internal returns (uint256, uint256, uint256) {
    Checkpoints.Trace208 storage items = $._items;

    uint32 offset_ = $._offset;
    uint256 reqLen = items.length();
    require(reqLen > offset_, LibRedeemQueue__NothingToClaim());

    uint256 found = items.upperBinaryLookup(timestamp, offset_, reqLen);
    require(found > offset_ + 1, LibRedeemQueue__NothingToClaim());

    uint256 solved = items.valueAt((found - 1).toUint32()) - items.valueAt(offset_);
    $._offset = (found - 1).toUint32();

    return (solved, offset_, found - 1);
  }

  // ================================= RedeemQueue ================================= //

  struct Request {
    uint256 accumulated;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
    bytes metadata;
  }

  struct Index {
    uint256 offset;
    uint256 size;
    mapping(uint256 index => uint256 itemIndex) data;
  }

  struct ReserveLog {
    uint256 accumulated;
    uint48 reservedAt;
    bytes metadata;
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
    uint256 redeemPeriod;
    ReserveLog[] reserveHistory;
    mapping(uint256 index => Request item) data;
    mapping(address recipient => Index index) indexes; // index request by recipient
  }

  uint256 constant DEFAULT_CLAIM_SIZE = 100;

  event Queued(address indexed recipient, uint256 requestIdx, uint256 amount);
  event Claimed(address indexed recipient, uint256 requestIdx);
  event Reserved(address indexed executor, uint256 amount, uint256 historyIndex);
  event QueueOffsetUpdated(uint256 oldOffset, uint256 newOffset);
  event IndexOffsetUpdated(address indexed recipient, uint256 oldOffset, uint256 newOffset);

  error LibRedeemQueue__EmptyIndex(address recipient);
  error LibRedeemQueue__IndexOutOfRange(uint256 index, uint256 from, uint256 to);
  error LibRedeemQueue__NotReadyToClaim(uint256 index);
  error LibRedeemQueue__InvalidRequestAmount();
  error LibRedeemQueue__InvalidReserveAmount();

  function isClaimed(Request memory x) internal pure returns (bool) {
    return x.claimedAt != 0;
  }

  function isReserved(Queue storage q, Request memory x) internal view returns (bool) {
    return q.reserveHistory.length != 0 && x.accumulated <= q.reserveHistory[q.reserveHistory.length - 1].accumulated;
  }

  function get(Queue storage q, uint256 itemIndex) internal view returns (Request memory) {
    require(itemIndex < q.size, LibRedeemQueue__IndexOutOfRange(itemIndex, 0, q.size - 1));
    return q.data[itemIndex];
  }

  function get(Index storage idx, uint256 i) internal view returns (uint256 itemIndex) {
    require(i < idx.size, LibRedeemQueue__IndexOutOfRange(i, 0, idx.size - 1));
    return idx.data[i];
  }

  function get(Queue storage q, Index storage idx, uint256 i) internal view returns (Request memory) {
    return get(q, get(idx, i));
  }

  function totalRequestAmount(Queue storage q) internal view returns (uint256) {
    return q.size == 0 ? 0 : q.data[q.size - 1].accumulated;
  }

  function totalReservedAmount(Queue storage q) internal view returns (uint256) {
    return q.reserveHistory.length == 0 ? 0 : q.reserveHistory[q.reserveHistory.length - 1].accumulated;
  }

  function totalPendingAmount(Queue storage q) internal view returns (uint256) {
    uint256 totalRequested = totalRequestAmount(q);
    uint256 totalReserved = totalReservedAmount(q);
    return totalRequested > totalReserved ? totalRequested - totalReserved : 0;
  }

  function requestAmount(Queue storage q, uint256 itemIndex) internal view returns (uint256) {
    uint256 accumulated = get(q, itemIndex).accumulated;
    uint256 prevAccumulated = itemIndex == 0 ? 0 : get(q, itemIndex - 1).accumulated;
    return accumulated - prevAccumulated;
  }

  function reserveLog(Queue storage q, uint256 itemIndex)
    internal
    view
    returns (ReserveLog memory reserveLog_, bool isReserved_)
  {
    Request memory req = get(q, itemIndex);
    return _searchReserveLog(q.reserveHistory, req.accumulated);
  }

  function reservedAt(Queue storage q, uint256 itemIndex) internal view returns (uint256 reservedAt_, bool isReserved_) {
    return _reservedAt(q, get(q, itemIndex));
  }

  function resolvedAt(Queue storage q, uint256 itemIndex, uint256 now_)
    internal
    view
    returns (uint256 resolvedAt_, bool isResolved_)
  {
    Request memory req = get(q, itemIndex);

    (uint256 reservedAt_, bool isReserved_) = _reservedAt(q, req);
    if (!isReserved_) return (0, false);

    uint256 redeemPeriodCheckpoint = req.createdAt + q.redeemPeriod;
    if (now_ < redeemPeriodCheckpoint) return (0, false);

    return (Math.min(reservedAt_, redeemPeriodCheckpoint), true);
  }

  function index(Queue storage q, address recipient) internal view returns (Index storage) {
    Index storage idx = q.indexes[recipient];
    require(idx.size != 0, LibRedeemQueue__EmptyIndex(recipient));
    return idx;
  }

  function claimable(Queue storage q, address recipient, uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256[] memory indexes)
  {
    Index storage idx = index(q, recipient);

    uint256 offset = idx.offset;
    (uint256 queueOffset,) = _searchQueueOffset(q, accumulated, timestamp, q.redeemPeriod);
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

  function searchQueueOffset(Queue storage q, uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256 offset, bool found)
  {
    return _searchQueueOffset(q, accumulated, timestamp, q.redeemPeriod);
  }

  function searchIndexOffset(Queue storage q, address recipient, uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256 offset, bool found)
  {
    return searchIndexOffset(q, recipient, accumulated, timestamp, q.redeemPeriod);
  }

  function searchIndexOffset(
    Queue storage q,
    address recipient,
    uint256 accumulated,
    uint256 timestamp,
    uint256 redeemPeriod
  ) internal view returns (uint256 offset, bool found) {
    (uint256 queueOffset,) = _searchQueueOffset(q, accumulated, timestamp, redeemPeriod);
    return _searchIndexOffset(q.indexes[recipient], queueOffset);
  }

  function searchReserveLog(Queue storage q, uint256 accumulated)
    internal
    view
    returns (ReserveLog memory log, bool found)
  {
    return _searchReserveLog(q.reserveHistory, accumulated);
  }

  function enqueue(Queue storage q, address recipient, uint256 amount, uint48 timestamp, bytes memory metadata)
    internal
    returns (uint256 itemIndex)
  {
    require(amount != 0, LibRedeemQueue__InvalidRequestAmount());

    bool isPrevItemExists = q.size > 0;
    itemIndex = q.size;

    // store request
    uint256 accumulated = amount;
    if (isPrevItemExists) {
      Request memory prevReq = q.data[itemIndex - 1];
      accumulated += prevReq.accumulated;
    }

    q.data[itemIndex] = Request({
      accumulated: accumulated,
      recipient: recipient,
      createdAt: timestamp,
      claimedAt: 0,
      metadata: metadata
    });
    q.size += 1;

    // submit index
    Index storage idx = q.indexes[recipient];
    idx.data[idx.size] = itemIndex;
    idx.size += 1;

    emit Queued(recipient, itemIndex, amount);

    return itemIndex;
  }

  function claim(Queue storage q, address recipient, uint48 timestamp) internal returns (uint256 totalClaimed_) {
    return claim(q, recipient, DEFAULT_CLAIM_SIZE, timestamp);
  }

  function claim(Queue storage q, address recipient, uint256 maxClaimSize, uint48 timestamp)
    internal
    returns (uint256 totalClaimed_)
  {
    _updateQueueOffset(q, totalReservedAmount(q), timestamp, q.redeemPeriod);

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
      q.data[itemIndex].claimedAt = timestamp;
      // simplified version of calculating request amount
      totalClaimed_ += itemIndex == 0 ? req.accumulated : req.accumulated - q.data[itemIndex - 1].accumulated;

      emit Claimed(recipient, itemIndex);
    }

    // update index offset if there's any claimed request
    if (totalClaimed_ > 0) idx.offset = i;

    return totalClaimed_;
  }

  function reserve(Queue storage q, address executor, uint256 amount, uint48 timestamp, bytes memory metadata)
    internal
    returns (uint256)
  {
    require(amount != 0, LibRedeemQueue__InvalidReserveAmount());
    uint256 historyIndex = q.reserveHistory.length;

    ReserveLog memory log = q.reserveHistory.length == 0
      ? ReserveLog({ accumulated: amount, reservedAt: timestamp, metadata: metadata })
      : ReserveLog({
        accumulated: q.reserveHistory[historyIndex - 1].accumulated + amount,
        reservedAt: timestamp,
        metadata: metadata
      });

    q.reserveHistory.push(log);

    _updateQueueOffset(q, log.accumulated, timestamp, q.redeemPeriod);

    emit Reserved(executor, amount, historyIndex);

    return historyIndex;
  }

  function update(Queue storage q, uint48 timestamp) internal returns (uint256 offset, bool updated) {
    return _updateQueueOffset(q, totalRequestAmount(q), timestamp, q.redeemPeriod);
  }

  function _reservedAt(Queue storage q, Request memory req)
    private
    view
    returns (uint256 reservedAt_, bool isReserved_)
  {
    if (!isReserved(q, req)) return (0, false);

    (ReserveLog memory log, bool found) = _searchReserveLog(q.reserveHistory, req.accumulated);
    if (!found) return (0, false);

    return (log.reservedAt, true);
  }

  function _updateQueueOffset(Queue storage q, uint256 accumulated, uint256 timestamp, uint256 redeemPeriod)
    private
    returns (uint256 offset, bool updated)
  {
    (offset, updated) = _searchQueueOffset(q, accumulated, timestamp, redeemPeriod);

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

  function _searchQueueOffset(Queue storage q, uint256 accumulated, uint256 timestamp, uint256 redeemPeriod)
    private
    view
    returns (uint256 offset, bool found)
  {
    offset = q.offset;

    uint256 low = offset;
    uint256 high = q.size;
    if (low == high) return (low, false);

    while (low < high) {
      uint256 mid = Math.average(low, high);
      Request memory req = q.data[mid];
      if (req.accumulated <= accumulated && req.createdAt + redeemPeriod <= timestamp) low = mid + 1;
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
      uint256 mid = Math.average(low, high);
      if (queueOffset > idx.data[mid]) low = mid + 1;
      else high = mid;
    }

    if (low == offset) return (low, false);
    return (low, true);
  }

  function _searchReserveLog(ReserveLog[] memory logs, uint256 accumulated)
    private
    pure
    returns (ReserveLog memory log, bool found)
  {
    uint256 low = 0;
    uint256 high = logs.length;
    if (low == high) return (log, false);

    // ensure accumulated is within the range of the logs
    if (accumulated < logs[low].accumulated || logs[high - 1].accumulated < accumulated) {
      return (log, false);
    }

    while (low < high) {
      uint256 mid = Math.average(low, high);
      if (logs[mid].accumulated < accumulated) low = mid + 1;
      else high = mid;
    }

    return (logs[low], true);
  }
}
