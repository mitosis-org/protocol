// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibRedeemQueue } from '../../../src/lib/LibRedeemQueue.sol';

contract RedeemQueueWrapper {
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

  function amount(uint256 itemIndex) external view returns (uint256) {
    return queue.amount(itemIndex);
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

  function totalReserved() external view returns (uint256) {
    return queue.totalReserved;
  }

  function totalClaimed() external view returns (uint256) {
    return queue.totalClaimed;
  }

  function reserveHistory() external view returns (LibRedeemQueue.ReserveLog[] memory) {
    return queue.reserveHistory;
  }

  function claimable(address recipient, uint256 accumulated) external view returns (uint256[] memory) {
    return queue.claimable(recipient, accumulated);
  }

  function searchQueueOffset(uint256 accumulated) external view returns (uint256 offset_, bool found) {
    return queue.searchQueueOffset(accumulated);
  }

  function searchIndexOffset(address recipient, uint256 accumulated)
    external
    view
    returns (uint256 offset_, bool found)
  {
    return queue.searchIndexOffset(recipient, accumulated);
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

  function enqueue(address recipient, uint256 requestAmount) external returns (uint256) {
    return queue.enqueue(recipient, requestAmount);
  }

  function claim(uint256 itemIndex) external {
    queue.claim(itemIndex);
  }

  function claim(uint256[] memory itemIndexes) external {
    queue.claim(itemIndexes);
  }

  function claim(address recipient) external {
    queue.claim(recipient);
  }

  function claim(address recipient, uint256 maxClaimSize) external {
    queue.claim(recipient, maxClaimSize);
  }

  function reserve(uint256 amount_) external {
    queue.reserve(amount_);
  }

  function update() external returns (uint256 offset_, bool updated) {
    return queue.update();
  }

  // =========================== NOTE: CONFIG FUNCTIONS =========================== //

  function setRedeemPeriod(uint256 redeemPeriod_) external {
    queue.redeemPeriod = redeemPeriod_;
  }
}
