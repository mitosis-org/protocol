// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibRedeemQueue } from '../../../src/lib/LibRedeemQueue.sol';

contract RedeemQueueWrapper {
  using SafeCast for uint256;
  using LibRedeemQueue for *;

  LibRedeemQueue.Queue private queue;

  // =========================== NOTE: QUERY FUNCTIONS =========================== //

  function get(uint256 itemIndex) external view returns (LibRedeemQueue.Request memory) {
    return queue.get(itemIndex);
  }

  function get(address recipient, uint256 itemIndex) external view returns (LibRedeemQueue.Request memory) {
    return queue.get(queue.index(recipient).get(itemIndex));
  }

  function getIndexItemId(address recipient, uint256 itemIndex) external view returns (uint256) {
    return queue.index(recipient).get(itemIndex);
  }

  function shares(uint256 itemIndex) external view returns (uint256) {
    return queue.shares(itemIndex);
  }

  function assets(uint256 itemIndex) external view returns (uint256) {
    return queue.assets(itemIndex);
  }

  function reservedAt(uint256 itemIndex) external view returns (uint256 reservedAt_, bool isReserved) {
    return queue.reservedAt(itemIndex);
  }

  function pending() external view returns (uint256) {
    return queue.pending();
  }

  function offset() external view returns (uint256) {
    return queue.offset;
  }

  function offset(address recipient) external view returns (uint256) {
    return queue.index(recipient).offset;
  }

  function size() external view returns (uint256) {
    return queue.size;
  }

  function size(address recipient) external view returns (uint256) {
    return queue.index(recipient).size;
  }

  function totalReservedAssets() external view returns (uint256) {
    return queue.totalReservedAssets;
  }

  function totalClaimedAssets() external view returns (uint256) {
    return queue.totalClaimedAssets;
  }

  function reserveHistory() external view returns (LibRedeemQueue.ReserveLog[] memory) {
    return queue.reserveHistory;
  }

  function claimable(address recipient, uint256 accumulated) external view returns (uint256[] memory) {
    return _claimable(recipient, accumulated, block.timestamp);
  }

  function claimable(address recipient, uint256 accumulated, uint256 timestamp)
    external
    view
    returns (uint256[] memory)
  {
    return _claimable(recipient, accumulated, timestamp);
  }

  function searchQueueOffset(uint256 accumulated) external view returns (uint256 offset_, bool found) {
    return _searchQueueOffset(accumulated, block.timestamp);
  }

  function searchQueueOffset(uint256 accumulated, uint256 timestamp)
    external
    view
    returns (uint256 offset_, bool found)
  {
    return _searchQueueOffset(accumulated, timestamp);
  }

  function searchIndexOffset(address recipient, uint256 accumulated)
    external
    view
    returns (uint256 offset_, bool found)
  {
    return _searchIndexOffset(recipient, accumulated, block.timestamp);
  }

  function searchIndexOffset(address recipient, uint256 accumulated, uint256 timestamp)
    external
    view
    returns (uint256 offset_, bool found)
  {
    return _searchIndexOffset(recipient, accumulated, timestamp);
  }

  function searchReserveLogByAccumulated(uint256 accumulated)
    external
    view
    returns (LibRedeemQueue.ReserveLog memory log, bool found)
  {
    return queue.searchReserveLogByAccumulated(accumulated);
  }

  function searchReserveLogByTimestamp(uint256 timestamp)
    external
    view
    returns (LibRedeemQueue.ReserveLog memory log, bool found)
  {
    return queue.searchReserveLogByTimestamp(timestamp);
  }

  // =========================== NOTE: QUEUE FUNCTIONS =========================== //

  function enqueue(address recipient, uint256 requestShares, uint256 requestAssets) external returns (uint256) {
    return queue.enqueue(recipient, requestShares, requestAssets, block.timestamp.toUint48());
  }

  function claim(uint256 itemIndex) external {
    queue.claim(itemIndex, block.timestamp.toUint48());
  }

  function claim(uint256[] memory itemIndexes) external {
    queue.claim(itemIndexes, block.timestamp.toUint48());
  }

  function claim(address recipient) external {
    queue.claim(recipient, block.timestamp.toUint48());
  }

  function claim(address recipient, uint256 maxClaimSize) external {
    queue.claim(recipient, maxClaimSize, block.timestamp.toUint48());
  }

  function reserve(uint256 amount_) external {
    queue.reserve(amount_, 1 ether, 1 ether, block.timestamp.toUint48());
  }

  function reserve(uint256 amount_, uint256 totalShares_, uint256 totalAssets_) external {
    queue.reserve(amount_, totalShares_.toUint208(), totalAssets_.toUint208(), block.timestamp.toUint48());
  }

  function update() external returns (uint256 offset_, bool updated) {
    return queue.update(block.timestamp.toUint48());
  }

  // =========================== NOTE: CONFIG FUNCTIONS =========================== //

  function setRedeemPeriod(uint256 redeemPeriod_) external {
    queue.redeemPeriod = redeemPeriod_;
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  function _claimable(address recipient, uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256[] memory)
  {
    return queue.claimable(recipient, accumulated, timestamp);
  }

  function _searchQueueOffset(uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256 offset_, bool found)
  {
    return queue.searchQueueOffset(accumulated, timestamp);
  }

  function _searchIndexOffset(address recipient, uint256 accumulated, uint256 timestamp)
    internal
    view
    returns (uint256 offset_, bool found)
  {
    return queue.searchIndexOffset(recipient, accumulated, timestamp);
  }
}
