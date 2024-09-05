// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAssetManagerStorageV1 {
  event EntrypointSet(address indexed entrypoint);
  event OptOutQueueSet(address indexed optOutQueue);
  event RewardManagerSet(address indexed rewardManager);

  function entrypoint() external view returns (address entrypoint_);

  function optOutQueue() external view returns (address optOutQueue_);

  function rewardManager() external view returns (address rewardManager_);

  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address branchAsset_);

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address hubAsset_);

  function eolIdle(address eolVault) external view returns (uint256 eolVaultIdleBalance);

  function eolAlloc(address eolVault) external view returns (uint256 eolVaultAllocation);
}

interface IAssetManager is IAssetManagerStorageV1 {
  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  function settleYield(uint256 chainId, address eolVault, uint256 amount) external;

  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external;

  function settleExtraRewards(uint256 chainId, address eolVault, address reward, uint256 amount) external;

  function initializeAsset(uint256 chainId, address hubAsset) external;

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external;

  function initializeEOL(uint256 chainId, address eolVault) external;
}
