// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IAssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event EntrypointSet(address indexed entrypoint);
  event OptOutQueueSet(address indexed optOutQueue);
  event RewardManagerSet(address indexed rewardManager);
  event StrategistSet(address indexed eolVault, address indexed strategist);

  //=========== NOTE: STATE GETTERS ===========//

  function entrypoint() external view returns (address entrypoint_);

  function optOutQueue() external view returns (address optOutQueue_);

  function rewardManager() external view returns (address rewardManager_);

  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address branchAsset_);

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address hubAsset_);

  function eolInitialized(uint256 chainId, address eolVault) external view returns (bool);

  function eolIdle(address eolVault) external view returns (uint256 eolVaultIdleBalance);

  function eolAlloc(address eolVault) external view returns (uint256 eolVaultAllocation);
}

interface IAssetManager is IAssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(uint256 indexed chainId, address asset);
  event EOLInitialized(uint256 indexed chainId, address eolVault, address asset);

  event Deposited(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);
  event DepositedWithOptIn(
    uint256 indexed chainId, address indexed asset, address indexed to, address eolVault, uint256 amount
  );
  event Redeemed(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);

  event RewardSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);
  event LossSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  event EOLShareValueDecreased(address indexed eolVault, uint256 indexed amount);

  event EOLAllocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);
  event EOLDeallocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IAssetManager__EOLInsufficient(address eolVault);
  error IAssetManager__InvalidEOLVault(address eolVault, address hubAsset);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function depositWithOptIn(uint256 chainId, address branchAsset, address to, address eolVault, uint256 amount)
    external;

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
