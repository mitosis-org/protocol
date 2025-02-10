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
   * @notice Emitted when a new reclaim queue is set
   * @param reclaimQueue_ The address of the new reclaim queue
   */
  event ReclaimQueueSet(address indexed reclaimQueue_);

  /**
   * @notice Emitted when a new reward treasury is set
   * @param treasury The address of the new treasury
   */
  event TreasurySet(address indexed treasury);

  /**
   * @notice Emitted when a new strategist is set for a MatrixVault
   * @param matrixVault The address of the MatrixVault
   * @param strategist The address of the new strategist
   */
  event StrategistSet(address indexed matrixVault, address indexed strategist);

  /**
   * @notice Emitted when the redeem status of a HubAsset is updated
   * @param hubAsset The address of the HubAsset
   * @param chainId The chain ID where the HubAsset status is being updated
   * @param available The new redeem status of the HubAsset (true if available, false if unavailable)
   */
  event HubAssetRedeemStatusSet(address indexed hubAsset, uint256 indexed chainId, bool available);

  /**
   * @notice Emitted when the liquidity threshold ratio for a HubAsset is updated.
   * @param hubAsset The address of the HubAsset.
   * @param chainId The chain ID where the liquidity threshold is being set.
   * @param thresholdRatio The new liquidity threshold ratio value for the HubAsset.
   */
  event HubAssetLiquidityThresholdRatioSet(address indexed hubAsset, uint256 indexed chainId, uint256 thresholdRatio);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IAssetManagerStorageV1__HubAssetPairNotExist(address hubAsset);
  error IAssetManagerStorageV1__HubAssetRedeemDisabled(address hubAsset, uint256 chainId);

  error IAssetManagerStorageV1__BranchAssetPairNotExist(address branchAsset);
  error IAssetManagerStorageV1__TreasuryNotSet();

  error IAssetManagerStorageV1__MatrixNotInitialized(uint256 chainId, address matrixVault);
  error IAssetManagerStorageV1__MatrixAlreadyInitialized(uint256 chainId, address matrixVault);

  error IAssetManagerStorageV1__BranchAvailableLiquidityInsufficient(
    uint256 chainId, address hubAsset, uint256 available, uint256 amount
  );

  error IAssetManagerStorageV1__BranchLiquidityNotInsufficient(
    uint256 chainId, address hubAsset, uint256 allocated, uint256 collateral, uint256 amount
  );

  //=========== NOTE: STATE GETTERS ===========//

  /**
   * @notice Get the current entrypoint address (see IAssetManagerEntrypoint)
   */
  function entrypoint() external view returns (address);

  /**
   * @notice Get the current reclaim queue address (see IReclaimQueue)
   */
  function reclaimQueue() external view returns (address);

  /**
   * @notice Get the current reward treasury address (see ITreasury)
   */
  function treasury() external view returns (address);

  /**
   * @notice Get the branch asset address for a given hub asset and chain ID
   * @param hubAsset_ The address of the hub asset
   * @param chainId The ID of the chain
   */
  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address);

  /**
   * @notice Check if a hub asset is redeemable on a given chain.
   * @dev This function returns a boolean indicating whether the specified hub asset
   *      can be redeemed on the given chain.
   * @param hubAsset_ The address of the hub asset.
   * @param chainId The ID of the target chain.
   * @return redeemable A boolean indicating whether the hub asset is redeemable on the given chain.
   */
  function hubAssetRedeemable(address hubAsset_, uint256 chainId) external view returns (bool);

  /**
   * @notice Get the precision used for the hub asset liquidity threshold ratio.
   * @dev This function returns the precision value used for representing the liquidity
   *      threshold ratio of hub assets. It ensures consistency in calculations.
   * @return The precision value for the liquidity threshold ratio.
   */
  function hubAssetLiquidityThresholdRatioPrecision() external view returns (uint256);

  /**
   * @notice Get the liquidity threshold ratio for a hub asset on a given chain.
   * @param hubAsset_ The address of the hub asset.
   * @param chainId The ID of the target chain.
   * @return thresholdRatio The liquidity threshold ratio for the hub asset on the given chain (0 ~ LIQUIDITY_THRESHOLD_RATIO_PERCISION).
   */
  function hubAssetLiquidityThresholdRatio(address hubAsset_, uint256 chainId) external view returns (uint256);

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
   * @notice Get the available liquidity of branch asset for a given chain ID and hub asset.
   * @dev The available amount of branch asset can be used for redemption or allocation.
   * @param chainId The ID of the chain
   * @param hubAsset_ The address of the hub asset
   */
  function branchAvailableLiquidity(uint256 chainId, address hubAsset_) external view returns (uint256);

  /**
   * @notice Check if a MatrixVault is initialized for a given chain and branch asset (MatrixVault -> hubAsset -> branchAsset)
   * @param chainId The ID of the chain
   * @param matrixVault The address of the MatrixVault
   */
  function matrixInitialized(uint256 chainId, address matrixVault) external view returns (bool);

  /**
   * @notice Get the idle balance of a MatrixVault
   * @dev The idle balance will be calculated like this:
   * @dev (total supplied amount - total utilized amount - total pending reclaim amount)
   * @param matrixVault The address of the MatrixVault
   */
  function matrixIdle(address matrixVault) external view returns (uint256);

  /**
   * @notice Get the total utilized balance (hubAsset/branchAsset) of a MatrixVault
   * @param matrixVault The address of the MatrixVault
   */
  function matrixAlloc(address matrixVault) external view returns (uint256);

  /**
   * @notice Get the strategist address for a MatrixVault
   * @param matrixVault The address of the MatrixVault
   */
  function strategist(address matrixVault) external view returns (address);
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
   * @notice Emitted when a MatrixVault is initialized
   * @param hubAsset The address of the hub asset
   * @param chainId The ID of the chain where the MatrixVault is initialized
   * @param matrixVault The address of the initialized MatrixVault
   * @param branchAsset The address of the branch asset associated with the MatrixVault
   */
  event MatrixInitialized(address indexed hubAsset, uint256 indexed chainId, address matrixVault, address branchAsset);

  /**
   * @notice Emitted when a deposit is made
   * @param chainId The ID of the chain where the deposit is made
   * @param hubAsset The address of the asset that correspond to the branch asset
   * @param to The address receiving the hubAsset
   * @param amount The amount deposited
   */
  event Deposited(uint256 indexed chainId, address indexed hubAsset, address indexed to, uint256 amount);

  /**
   * @notice Emitted when a deposit is made with supply to a MatrixVault
   * @param chainId The ID of the chain where the deposit is made
   * @param hubAsset The address of the asset that correspond to the branch asset
   * @param to The address receiving the miAsset
   * @param matrixVault The address of the MatrixVault supplied into
   * @param amount The amount deposited
   * @param supplyAmount The amount supplied into the MatrixVault
   */
  event DepositedWithSupplyMatrix(
    uint256 indexed chainId,
    address indexed hubAsset,
    address indexed to,
    address matrixVault,
    uint256 amount,
    uint256 supplyAmount
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
   * @notice Emitted when a reward is settled from the branch chain to the hub chain for a specific MatrixVault
   * @param chainId The ID of the chain where the reward is reported
   * @param matrixVault The address of the MatrixVault receiving the reward
   * @param asset The address of the reward asset
   * @param amount The amount of the reward
   */
  event MatrixRewardSettled(
    uint256 indexed chainId, address indexed matrixVault, address indexed asset, uint256 amount
  );

  /**
   * @notice Emitted when a loss is settled from the branch chain to the hub chain for a specific MatrixVault
   * @param chainId The ID of the chain where the loss is reported
   * @param matrixVault The address of the MatrixVault incurring the loss
   * @param asset The address of the asset lost
   * @param amount The amount of the loss
   */
  event MatrixLossSettled(uint256 indexed chainId, address indexed matrixVault, address indexed asset, uint256 amount);

  /**
   * @notice Emitted when assets are allocated to the branch chain for a specific MatrixVault
   * @param chainId The ID of the chain where the allocation occurs
   * @param matrixVault The address of the MatrixVault to be reported the allocation
   * @param amount The amount allocated
   */
  event MatrixAllocated(uint256 indexed chainId, address indexed matrixVault, uint256 amount);

  /**
   * @notice Emitted when assets are deallocated from the branch chain for a specific MatrixVault
   * @param chainId The ID of the chain where the deallocation occurs
   * @param matrixVault The address of the MatrixVault to be reported the deallocation
   * @param amount The amount deallocated
   */
  event MatrixDeallocated(uint256 indexed chainId, address indexed matrixVault, uint256 amount);

  /**
   * @notice Emitted when an asset pair is set
   * @param hubAsset The address of the hub asset
   * @param branchChainId The ID of the branch chain
   * @param branchAsset The address of the branch asset
   */
  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);

  /**
   * @notice Error thrown when an invalid MatrixVault address does not match with the hub asset
   * @param matrixVault The address of the invalid MatrixVault
   * @param hubAsset The address of the hub asset
   */
  error IAssetManager__InvalidMatrixVault(address matrixVault, address hubAsset);

  /**
   * @notice Error thrown when a MatrixVault has insufficient funds
   * @param matrixVault The address of the MatrixVault with insufficient funds
   */
  error IAssetManager__MatrixInsufficient(address matrixVault);

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
   * @notice Deposit branch assets with supply to a MatrixVault
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the deposit is made
   * @param branchAsset The address of the branch asset being deposited
   * @param to The address receiving the deposit
   * @param matrixVault The address of the MatrixVault to supply into
   * @param amount The amount to deposit
   */
  function depositWithSupplyMatrix(
    uint256 chainId,
    address branchAsset,
    address to,
    address matrixVault,
    uint256 amount
  ) external;

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
   * @notice Allocate the assets to the branch chain for a specific MatrixVault
   * @dev Only the strategist of the MatrixVault can allocate assets
   * @dev Dispatches the cross-chain message to branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the allocation occurs
   * @param matrixVault The address of the MatrixVault to be affected
   * @param amount The amount to allocate
   */
  function allocateMatrix(uint256 chainId, address matrixVault, uint256 amount) external;

  /**
   * @notice Deallocate the assets from the branch chain for a specific MatrixVault
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the deallocation occurs
   * @param matrixVault The address of the MatrixVault to be affected
   * @param amount The amount to deallocate
   */
  function deallocateMatrix(uint256 chainId, address matrixVault, uint256 amount) external;

  /**
   * @notice Resolves the pending reclaim request amount from the reclaim queue using the idle balance of a MatrixVault
   * @param matrixVault The address of the MatrixVault
   * @param amount The amount to reserve
   */
  function reserveMatrix(address matrixVault, uint256 amount) external;

  /**
   * @notice Settles an yield generated from Matrix Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the yield is settled
   * @param matrixVault The address of the MatrixVault to be affected
   * @param amount The amount of yield to settle
   */
  function settleMatrixYield(uint256 chainId, address matrixVault, uint256 amount) external;

  /**
   * @notice Settles a loss incurred by the Matrix Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the loss is settled
   * @param matrixVault The address of the MatrixVault to be affected
   * @param amount The amount of loss to settle
   */
  function settleMatrixLoss(uint256 chainId, address matrixVault, uint256 amount) external;

  /**
   * @notice Settle extra rewards generated from Matrix Protocol
   * @dev Processes the cross-chain message from the branch chain (see IAssetManagerEntrypoint)
   * @param chainId The ID of the chain where the rewards are settled
   * @param matrixVault The address of the MatrixVault
   * @param branchReward The address of the reward asset on the branch chain
   * @param amount The amount of extra rewards to settle
   */
  function settleMatrixExtraRewards(uint256 chainId, address matrixVault, address branchReward, uint256 amount)
    external;

  /**
   * @notice Initialize an asset for a given chain's MitosisVault
   * @param chainId The ID of the chain where the asset is initialized
   * @param hubAsset The address of the hub asset to initialize on the branch chain
   */
  function initializeAsset(uint256 chainId, address hubAsset) external;

  /**
   * @notice Set the redeem status for a hub asset on a given chain.
   * @param chainId The ID of the chain where the redeem status is being set
   * @param hubAsset The address of the hub asset for which the redeem status is being updated
   * @param available A boolean indicating whether the hub asset is available for redemption (true) or not (false)
   */
  function setHubAssetRedeemStatus(uint256 chainId, address hubAsset, bool available) external;

  /**
   * @notice Set the liquidity threshold ratio for a hub asset on a given chain.
   * @param chainId The ID of the chain where the liquidity threshold ratio is being set.
   * @param hubAsset The address of the hub asset for which the liquidity threshold ratio is being set.
   * @param thresholdRatio The new liquidity threshold ratio for the hub asset on the given chain (0 ~ LIQUIDITY_THRESHOLD_RATIO_PERCISION).
   */
  function setHubAssetLiquidityThresholdRatio(uint256 chainId, address hubAsset, uint256 thresholdRatio) external;

  /**
   * @notice Set liquidity threshold ratios for multiple hub assets on multiple chains.
   * @dev This function allows the owner or authorized user to set liquidity threshold ratios for multiple hub assets at once, on multiple chains.
   * @param chainIds An array of chain IDs where the liquidity threshold ratios are being set.
   * @param hubAssets An array of hub asset addresses for which the liquidity threshold ratios are being set.
   * @param thresholdRatios An array of new liquidity threshold ratios corresponding to the hub assets on the given chains.
   */
  function setHubAssetLiquidityThresholdRatio(
    uint256[] calldata chainIds,
    address[] calldata hubAssets,
    uint256[] calldata thresholdRatios
  ) external;

  /**
   * @notice Initialize a Matrix for branch asset (MatrixVault) on a given chain
   * @param chainId The ID of the chain where the MatrixVault is initialized
   * @param matrixVault The address of the MatrixVault to initialize
   */
  function initializeMatrix(uint256 chainId, address matrixVault) external;

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
   * @notice Set the reclaim queue address
   * @param reclaimQueue_ The new reclaim queue address
   */
  function setReclaimQueue(address reclaimQueue_) external;

  /**
   * @notice Set the reward treasury address
   * @param treasury_ The new treasury address
   */
  function setTreasury(address treasury_) external;

  /**
   * @notice Set the strategist for a MatrixVault
   * @param matrixVault The address of the MatrixVault
   * @param strategist The address of the new strategist
   */
  function setStrategist(address matrixVault, address strategist) external;
}
