// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from './IAssetManager.sol';

/**
 * @title IAssetManagerEntrypoint
 * @notice Interface for the Asset Manager Entrypoint, which serves as a bridge between the Asset Manager and branch chains
 * @dev This interface defines the methods for cross-chain asset management operations
 */
interface IAssetManagerEntrypoint {
  /**
   * @notice Returns the address of the associated Asset Manager contract
   */
  function assetManager() external view returns (IAssetManager);

  /**
   * @notice Retrieves the Hyperlane domain for a given chain ID
   * @param chainId The ID of the chain to query
   * @return The Hyperlane domain associated with the given chain ID
   */
  function branchDomain(uint256 chainId) external view returns (uint32);

  /**
   * @notice Gets the address of the branch vault for a specific chain
   * @param chainId The ID of the chain to query
   * @return The address of the branch vault on the specified chain
   */
  function branchVault(uint256 chainId) external view returns (address);

  /**
   * @notice Retrieves the address of the branch entrypoint for a given chain
   * @param chainId The ID of the chain to query
   * @return The address of the branch entrypoint on the specified chain
   */
  function branchEntrypointAddr(uint256 chainId) external view returns (address);

  /**
   * @notice Initializes an asset on a specified branch chain
   * @param chainId The ID of the branch chain
   * @param branchAsset The address of the asset on the branch chain
   */
  function initializeAsset(uint256 chainId, address branchAsset) external;

  /**
   * @notice Initializes an EOLVault on a specified branch chain
   * @param chainId The ID of the branch chain
   * @param eolVault The address of the EOLVault
   * @param branchAsset The address of the associated asset on the branch chain
   */
  function initializeEOL(uint256 chainId, address eolVault, address branchAsset) external;

  /**
   * @notice Initiates a redemption of assets from a branch chain
   * @param chainId The ID of the branch chain
   * @param branchAsset The address of the asset on the branch chain
   * @param to The address that will receive the redeemed assets
   * @param amount The amount of assets to redeem
   */
  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  /**
   * @notice Allocates assets to the StrategyExecutor for MitosisVault on branch chain that corresponed to the EOLVault on hub chain
   * @param chainId The ID of the branch chain
   * @param eolVault The address of the EOLVault
   * @param amount The amount of assets to allocate
   */
  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;
}
