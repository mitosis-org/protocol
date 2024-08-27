// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRewardDistributor {
  struct Batch {
    uint256 totalReward;
    uint48 startedAt;
    uint48 endedAt;
  }

  // BatchStorage is assigned per (eolId, asset).
  struct BatchStorage {
    uint256 currentBatchId;
    mapping(uint256 batchId => Batch batch) batches;
  }

  function nextBatch(uint256 eolId, address asset) external returns (uint256);

  function dispatch(uint256 eolId, address asset, uint256 amount, uint48 rewardedAt) external;

  function claim(uint256 eolId, address asset, uint256 batchId) external;
  function claim(uint256 eolId, address asset, uint256 batchId, uint256 amountsClaimed) external;

  function claim(uint256 eolId, address asset, uint256 batchId, bytes32[] calldata proof) external;
  function claim(uint256 eolId, address asset, uint256 batchId, uint256 amountsClaimed, bytes32[] calldata proof)
    external;
}
