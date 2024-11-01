// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IAssetManagerStorageV1
 * @notice Interface for the storage component of the AssetManager
 */
interface IAssetManagerStorageV1 {
  /**
   * @notice Emitted when a new entrypoint is set
   * @param entrypoint The address of the new entrypoint
   */
  event EntrypointSet(address indexed entrypoint);

  /**
   * @notice Emitted when a new opt-out queue is set
   * @param optOutQueue_ The address of the new opt-out queue
   */
  event OptOutQueueSet(address indexed optOutQueue_);

  /**
   * @notice Emitted when a new reward handler is set
   * @param rewardHandler The address of the new reward handler
   */
  event RewardHandlerSet(address indexed rewardHandler);

  /**
   * @notice Emitted when a new strategist is set for an EOLVault
   * @param eolVault The address of the EOLVault
   * @param strategist The address of the new strategist
   */
  event StrategistSet(address indexed eolVault, address indexed strategist);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IAssetManagerStorageV1__BranchAssetPairNotExist(address branchAsset);
  error IAssetManagerStorageV1__RewardHandlerNotSet();

  error IAssetManagerStorageV1__EOLNotInitialized(uint256 chainId, address eolVault);
  error IAssetManagerStorageV1__EOLAlreadyInitialized(uint256 chainId, address eolVault);

  //=========== NOTE: STATE GETTERS ===========//

  /**
   * @notice Get the current entrypoint address (see IAssetManagerEntrypoint)
   */
  function entrypoint() external view returns (address);

  /**
   * @notice Get the current opt-out queue address (see IOptOutQueue)
   */
  function optOutQueue() external view returns (address);

  /**
   * @notice Get the current reward handler address (see IRewardHandler)
   */
  function rewardHandler() external view returns (address);

  /**
   * @notice Get the branch asset address for a given hub asset and chain ID
   * @param hubAsset_ The address of the hub asset
   * @param chainId The ID of the chain
   */
  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address);

  /**
   * @notice Get the hub asset address for a given chain ID and branch asset
   * @param chainId The ID of the chain
   * @param branchAsset_ The address of the branch asset
   */
  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address);

  /**
   * @notice Get the total collateral amount of branch asset for a given chain ID and hub asset.
   * @dev The collateral amount is equals to the total amount of branch asset deposited to the MitosisVault
   * @param chainId The ID of the chain
   * @param hubAsset_ The address of the hub asset
   */
  function collateral(uint256 chainId, address hubAsset_) external view returns (uint256);

  /**
   * @notice Check if an EOLVault is initialized for a given chain and branch asset (EOLVault -> hubAsset -> branchAsset)
   * @param chainId The ID of the chain
   * @param eolVault The address of the EOLVault
   */
  function eolInitialized(uint256 chainId, address eolVault) external view returns (bool);

  /**
   * @notice Get the idle balance of an EOLVault
   * @dev The idle balance will be calculated like this:
   * @dev (total opt-in amount - total utilized amount - total pending opt-out amount)
   * @param eolVault The address of the EOLVault
   */
  function eolIdle(address eolVault) external view returns (uint256);

  /**
   * @notice Get the total utilized balance (hubAsset/branchAsset) of an EOLVault
   * @param eolVault The address of the EOLVault
   */
  function eolAlloc(address eolVault) external view returns (uint256);

  /**
   * @notice Get the strategist address for an EOLVault
   * @param eolVault The address of the EOLVault
   */
  function strategist(address eolVault) external view returns (address);
}

/**
 * @title IAssetManager
 * @notice Interface for the main Asset Manager contract
 */
interface IAssetManager is IAssetManagerStorageV1 {
  /**
   * @notice Emitted when an asset is initialized
   * @param hubAsset The address of the hub asset
   * @param chainId The ID of the chain where the asset is initialized
   * @param branchAsset The address of the initialized branch asset
   */
  event AssetInitialized(address indexed hubAsset, uint256 indexed chainId, address branchAsset);

  /**
   * @notice Emitted when an EOLVault is initialized
   * @param hubAsset The address of the hub asset
   * @param chainId The ID of the chain where the EOLVault is initialized
   * @param eolVault The address of the initialized EOLVault
   * @param branchAsset The address of the branch asset associated with the EOLVault
   */
  event EOLInitialized(address indexed hubAsset, uint256 indexed chainId, address eolVault, address branchAsset);

  /**
   * @notice Emitted when a deposit is made
   * @param chainId The ID of the chain where the deposit is made
   * @param hubAsset The address of the asset that correspond to the branch asset
   * @param to The address receiving the hubAsset
   * @param amount The amount deposited
   */
  event Deposited(uint256 indexed chainId, address indexed hubAsset, address indexed to, uint256 amount);

  /**
   * @notice Emitted when a deposit is made with opt-in
   * @param chainId The ID of the chain where the deposit is made
   * @param hubAsset The address of the asset that correspond to the branch asset
   * @param to The address receiving the miAsset
   * @param eolVault The address of the EOLVault opted into
   * @param amount The amount deposited
   * @param optInAmount The amount opted into the EOLVault
   */
  event DepositedWithOptIn(
    uint256 indexed chainId,
    address indexed hubAsset,
    address indexed to,
    address eolVault,
    uint256 amount,
    uint256 optInAmount
  );

  /**
   * @notice Emitted when hubAssets are redeemed
   * @param chainId The ID of the chain where the redemption occurs
   * @param hubAsset The address of the redeemed asset
   * @param to The address receiving the redeemed assets on the branch chain
   * @param amount The hubAsset amount to be redeemed
   */
  event Redeemed(uint256 indexed chainId, address indexed hubAsset, address indexed to, uint256 amount);

  /**
   * @notice Emitted when a reward is settled from the branch chain to the hub chain for a specific EOLVault
   * @param chainId The ID of the chain where the reward is reported
   * @param eolVault The address of the EOLVault receiving the reward
   * @param asset The address of the reward asset
   * @param amount The amount of the reward
   */
  event RewardSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  /**
   * @notice Emitted when a loss is settled from the branch chain to the hub chain for a specific EOLVault
   * @param chainId The ID of the chain where the loss is reported
   * @param eolVault The address of the EOLVault incurring the loss
   * @param asset The address of the asset lost
   * @param amount The amount of the loss
   */
  event LossSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  /**
   * @notice Emitted when assets are allocated to the branch chain for a specific EOLVault
   * @param chainId The ID of the chain where the allocation occurs
   * @param eolVault The address of the EOLVault to be reported the allocation
   * @param amount The amount allocated
   */
  event EOLAllocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  /**
   * @notice Emitted when assets are deallocated from the branch chain for a specific EOLVault
   * @param chainId The ID of the chain where the deallocation occurs
   * @param eolVault The address of the EOLVault to be reported the deallocation
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
   * @notice Error thrown when the total collateral for a given chain ID and hub asset is insufficient
   * @param chainId The ID of the chain
   * @param hubAsset The address of the hub asset
   * @param collateral The total collateral amount for a given chain ID and hub asset
   * @param amount The required amount for the operation
   */
  error IAssetManager__CollateralInsufficient(uint256 chainId, address hubAsset, uint256 collateral, uint256 amount);

  /**
   * @notice Error thrown when an invalid EOLVault address does not match with the hub asset
   * @param eolVault The address of the invalid EOLVault
   * @param hubAsset The address of the hub asset
   */
  error IAssetManager__InvalidEOLVault(address eolVault, address hubAsset);

  /**
   * @notice Error thrown when an EOLVault has insufficient funds
   * @param eolVault The address of the EOLVault with insufficient funds
   */
  error IAssetManager__EOLInsufficient(address eolVault);

  /**
   * @notice Deposit branch assets
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the deposit is made
   * @param branchAsset The address of the branch asset being deposited
   * @param to The address receiving the deposit
   * @param amount The amount to deposit
   */
  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  /**
   * @notice Deposit branch assets with opt-in to an EOLVault
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the deposit is made
   * @param branchAsset The address of the branch asset being deposited
   * @param to The address receiving the deposit
   * @param eolVault The address of the EOLVault to opt into
   * @param amount The amount to deposit
   */
  function depositWithOptIn(uint256 chainId, address branchAsset, address to, address eolVault, uint256 amount)
    external;

  /**
   * @notice Redeem hub assets and receive the asset on the branch chain
   * @dev Dispatches the cross-chain message to branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the redemption occurs
   * @param hubAsset The address of the hub asset to redeem
   * @param to The address receiving the redeemed assets
   * @param amount The amount to redeem
   */
  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external;

  /**
   * @notice Allocate the assets to the branch chain for a specific EOLVault
   * @dev Only the strategist of the EOLVault can allocate assets
   * @dev Dispatches the cross-chain message to branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the allocation occurs
   * @param eolVault The address of the EOLVault to be affected
   * @param amount The amount to allocate
   */
  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Deallocate the assets from the branch chain for a specific EOLVault
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the deallocation occurs
   * @param eolVault The address of the EOLVault to be affected
   * @param amount The amount to deallocate
   */
  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Resolves the pending opt-out request amount from the opt-out queue using the idle balance of an EOLVault
   * @param eolVault The address of the EOLVault
   * @param amount The amount to reserve
   */
  function reserveEOL(address eolVault, uint256 amount) external;

  /**
   * @notice Settles an yield generated from EOL Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the yield is settled
   * @param eolVault The address of the EOLVault to be affected
   * @param amount The amount of yield to settle
   */
  function settleYield(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Settles a loss incurred by the EOL Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the loss is settled
   * @param eolVault The address of the EOLVault to be affected
   * @param amount The amount of loss to settle
   */
  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external;

  /**
   * @notice Settle extra rewards generated from EOL Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the rewards are settled
   * @param eolVault The address of the EOLVault
   * @param branchReward The address of the reward asset on the branch chain
   * @param amount The amount of extra rewards to settle
   */
  function settleExtraRewards(uint256 chainId, address eolVault, address branchReward, uint256 amount) external;

  /**
   * @notice Initialize an asset for a given chain's MitosisVault
   * @param chainId The ID of the chain where the asset is initialized
   * @param hubAsset The address of the hub asset to initialize on the branch chain
   */
  function initializeAsset(uint256 chainId, address hubAsset) external;

  /**
   * @notice Initialize an EOL for branch asset (EOLVault) on a given chain
   * @param chainId The ID of the chain where the EOLVault is initialized
   * @param eolVault The address of the EOLVault to initialize
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
   * @notice Set the reward handler address
   * @param rewardHandler_ The new reward handler address
   */
  function setRewardHandler(address rewardHandler_) external;

  /**
   * @notice Set the strategist for an EOLVault
   * @param eolVault The address of the EOLVault
   * @param strategist The address of the new strategist
   */
  function setStrategist(address eolVault, address strategist) external;
}
