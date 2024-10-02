// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IAssetManagerStorageV1
 * @notice Interface for the storage component of the Asset Manager
 */
interface IAssetManagerStorageV1 {
  /**
   * @notice Emitted when a new entrypoint is set
   * @param entrypoint_ The address of the new entrypoint
   */
  event EntrypointSet(address indexed entrypoint_);

  /**
   * @notice Emitted when a new opt-out queue is set
   * @param optOutQueue_ The address of the new opt-out queue
   */
  event OptOutQueueSet(address indexed optOutQueue_);

  /**
   * @notice Emitted when a new reward router is set
   * @param rewardRouter_ The address of the new reward router
   */
  event RewardRouterSet(address indexed rewardRouter_);

  /**
   * @notice Emitted when a new strategist is set for an EOL vault
   * @param eolVault The address of the EOL vault
   * @param strategist The address of the new strategist
   */
  event StrategistSet(address indexed eolVault, address indexed strategist);

  /**
   * @notice Get the current entrypoint address
   * @return entrypoint_ The address of the current entrypoint
   */
  function entrypoint() external view returns (address entrypoint_);

  /**
   * @notice Get the current opt-out queue address
   * @return optOutQueue_ The address of the current opt-out queue
   */
  function optOutQueue() external view returns (address optOutQueue_);

  /**
   * @notice Get the current reward router address
   * @return rewardRouter_ The address of the current reward router
   */
  function rewardRouter() external view returns (address rewardRouter_);

  /**
   * @notice Get the branch asset address for a given hub asset and chain ID
   * @param hubAsset_ The address of the hub asset
   * @param chainId The ID of the chain
   * @return branchAsset_ The address of the corresponding branch asset
   */
  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address branchAsset_);

  /**
   * @notice Get the hub asset address for a given chain ID and branch asset
   * @param chainId The ID of the chain
   * @param branchAsset_ The address of the branch asset
   * @return hubAsset_ The address of the corresponding hub asset
   */
  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address hubAsset_);

  /**
   * @notice Get the collateral amount for a given chain ID and hub asset
   * @param chainId The ID of the chain
   * @param hubAsset_ The address of the hub asset
   * @return collateral_ The amount of collateral
   */
  function collateral(uint256 chainId, address hubAsset_) external view returns (uint256 collateral_);

  /**
   * @notice Check if an EOL vault is initialized for a given chain
   * @param chainId The ID of the chain
   * @param eolVault The address of the EOL vault
   * @return  eolInitialized_ A boolean indicating whether the EOL vault is initialized
   */
  function eolInitialized(uint256 chainId, address eolVault) external view returns (bool eolInitialized_);

  /**
   * @notice Get the idle balance of an EOL vault
   * @param eolVault The address of the EOL vault
   * @return eolVaultIdleBalance The idle balance of the EOL vault
   */
  function eolIdle(address eolVault) external view returns (uint256 eolVaultIdleBalance);

  /**
   * @notice Get the allocation of an EOL vault
   * @param eolVault The address of the EOL vault
   * @return eolVaultAllocation The allocation of the EOL vault
   */
  function eolAlloc(address eolVault) external view returns (uint256 eolVaultAllocation);

  /**
   * @notice Get the strategist address for an EOL vault
   * @param eolVault The address of the EOL vault
   * @return strategist_ The address of the strategist
   */
  function strategist(address eolVault) external view returns (address strategist_);
}

/**
 * @title IAssetManager
 * @notice Interface for the main Asset Manager contract
 */
interface IAssetManager is IAssetManagerStorageV1 {
  /**
   * @notice Emitted when an asset is initialized
   * @param chainId The ID of the chain where the asset is initialized
   * @param asset The address of the initialized asset
   */
  event AssetInitialized(uint256 indexed chainId, address asset);

  /**
   * @notice Emitted when an EOL vault is initialized
   * @param chainId The ID of the chain where the EOL vault is initialized
   * @param eolVault The address of the initialized EOL vault
   * @param asset The address of the asset associated with the EOL vault
   */
  event EOLInitialized(uint256 indexed chainId, address eolVault, address asset);

  /**
   * @notice Emitted when a deposit is made
   * @param chainId The ID of the chain where the deposit is made
   * @param asset The address of the deposited asset
   * @param to The address receiving the deposit
   * @param amount The amount deposited
   */
  event Deposited(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);

  /**
   * @notice Emitted when a deposit is made with opt-in
   * @param chainId The ID of the chain where the deposit is made
   * @param asset The address of the deposited asset
   * @param to The address receiving the deposit
   * @param eolVault The address of the EOL vault opted into
   * @param amount The amount deposited
   */
  event DepositedWithOptIn(
    uint256 indexed chainId, address indexed asset, address indexed to, address eolVault, uint256 amount
  );

  /**
   * @notice Emitted when assets are redeemed
   * @param chainId The ID of the chain where the redemption occurs
   * @param asset The address of the redeemed asset
   * @param to The address receiving the redeemed assets
   * @param amount The amount redeemed
   */
  event Redeemed(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);

  /**
   * @notice Emitted when a reward is settled
   * @param chainId The ID of the chain where the reward is settled
   * @param eolVault The address of the EOL vault receiving the reward
   * @param asset The address of the reward asset
   * @param amount The amount of the reward
   */
  event RewardSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  /**
   * @notice Emitted when a loss is settled
   * @param chainId The ID of the chain where the loss is settled
   * @param eolVault The address of the EOL vault incurring the loss
   * @param asset The address of the asset lost
   * @param amount The amount of the loss
   */
  event LossSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  /**
   * @notice Emitted when assets are allocated to an EOL vault
   * @param chainId The ID of the chain where the allocation occurs
   * @param eolVault The address of the EOL vault receiving the allocation
   * @param amount The amount allocated
   */
  event EOLAllocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  /**
   * @notice Emitted when assets are deallocated from an EOL vault
   * @param chainId The ID of the chain where the deallocation occurs
   * @param eolVault The address of the EOL vault from which assets are deallocated
   * @param amount The amount deallocated
   */
  event EOLDeallocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  /**
   * @notice Emitted when an asset pair is set
   * @param hubAsset The address of the hub asset
   * @param branchChainId The ID of the branch chain
   * @param branchAsset The address of the branch asset
   */
  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);

  /**
   * @notice Error thrown when an EOL vault has insufficient funds
   * @param eolVault The address of the EOL vault with insufficient funds
   */
  error IAssetManager__EOLInsufficient(address eolVault);

  /**
   * @notice Error thrown when an invalid EOL vault is provided
   * @param eolVault The address of the invalid EOL vault
   * @param hubAsset The address of the hub asset
   */
  error IAssetManager__InvalidEOLVault(address eolVault, address hubAsset);

  /**
   * @notice Deposit assets
   * @param chainId The ID of the chain where the deposit is made
   * @param branchAsset The address of the branch asset being deposited
   * @param to The address receiving the deposit
   * @param amount The amount to deposit
   */
  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  /**
   * @notice Deposit assets with opt-in to an EOL vault
   * @param chainId The ID of the chain where the deposit is made
   * @param branchAsset The address of the branch asset being deposited
   * @param to The address receiving the deposit
   * @param eolVault The address of the EOL vault to opt into
   * @param amount The amount to deposit
   */
  function depositWithOptIn(uint256 chainId, address branchAsset, address to, address eolVault, uint256 amount)
    external;

  /**
   * @notice Redeem assets
   * @param chainId The ID of the chain where the redemption occurs
   * @param branchAsset The address of the branch asset being redeemed
   * @param to The address receiving the redeemed assets
   * @param amount The amount to redeem
   */
  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  /**
   * @notice Allocate assets to an EOL vault
   * @param chainId The ID of the chain where the allocation occurs
   * @param eolVault The address of the EOL vault receiving the allocation
   * @param amount The amount to allocate
   */
  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Deallocate assets from an EOL vault
   * @param chainId The ID of the chain where the deallocation occurs
   * @param eolVault The address of the EOL vault from which assets are deallocated
   * @param amount The amount to deallocate
   */
  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Reserve assets in an EOL vault
   * @param eolVault The address of the EOL vault
   * @param amount The amount to reserve
   */
  function reserveEOL(address eolVault, uint256 amount) external;

  /**
   * @notice Settle yield for an EOL vault
   * @param chainId The ID of the chain where the yield is settled
   * @param eolVault The address of the EOL vault
   * @param amount The amount of yield to settle
   */
  function settleYield(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Settle loss for an EOL vault
   * @param chainId The ID of the chain where the loss is settled
   * @param eolVault The address of the EOL vault
   * @param amount The amount of loss to settle
   */
  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Settle extra rewards for an EOL vault
   * @param chainId The ID of the chain where the rewards are settled
   * @param eolVault The address of the EOL vault
   * @param branchReward The address of the branch reward asset
   * @param amount The amount of extra rewards to settle
   */
  function settleExtraRewards(uint256 chainId, address eolVault, address branchReward, uint256 amount) external;

  /**
   * @notice Initialize an asset
   * @param chainId The ID of the chain where the asset is initialized
   * @param hubAsset The address of the hub asset to initialize
   */
  function initializeAsset(uint256 chainId, address hubAsset) external;

  /**
   * @notice Initialize an EOL vault
   * @param chainId The ID of the chain where the EOL vault is initialized
   * @param eolVault The address of the EOL vault to initialize
   */
  function initializeEOL(uint256 chainId, address eolVault) external;

  /**
   * @notice Set an asset pair
   * @param hubAsset The address of the hub asset
   * @param branchChainId The ID of the branch chain
   * @param branchAsset The address of the branch asset
   */
  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external;

  /**
   * @notice Set the entrypoint address
   * @param entrypoint_ The new entrypoint address
   */
  function setEntrypoint(address entrypoint_) external;

  /**
   * @notice Set the opt-out queue address
   * @param optOutQueue_ The new opt-out queue address
   */
  function setOptOutQueue(address optOutQueue_) external;

  /**
   * @notice Set the reward router address
   * @param rewardRouter_ The new reward router address
   */
  function setRewardRouter(address rewardRouter_) external;

  /**
   * @notice Set the strategist for an EOL vault
   * @param eolVault The address of the EOL vault
   * @param strategist The address of the new strategist
   */
  function setStrategist(address eolVault, address strategist) external;
}
