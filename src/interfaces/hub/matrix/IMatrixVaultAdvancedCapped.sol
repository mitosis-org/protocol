// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMatrixVaultCapped } from './IMatrixVaultCapped.sol';

/**
 * @title IMatrixVaultAdvancedCapped
 * @notice Extended interface for MatrixVaultCapped with soft cap and preferred chain bypass features
 */
interface IMatrixVaultAdvancedCapped is IMatrixVaultCapped {
  /**
   * @notice Returns the current soft cap value
   * @return The soft cap amount
   */
  function loadSoftCap() external view returns (uint256);

  /**
   * @notice Check if a chain ID is a preferred chain for bypass
   * @param chainId The chain ID to check
   * @return isPreferred True if the chain allows soft cap bypass
   */
  function isPreferredChain(uint256 chainId) external view returns (bool);

  /**
   * @notice Get all preferred chain IDs
   * @return Array of preferred chain IDs
   */
  function preferredChainIds() external view returns (uint256[] memory);

  /**
   * @notice Returns the maximum amount of assets that can be deposited for a specific chain
   * @dev This function is only callable by the AssetManager
   * @param receiver The address receiving the shares
   * @param chainId The chain ID where the deposit originates
   * @return maxAssets The maximum deposit amount considering chain-specific bypass rules
   */
  function maxDepositForChainId(address receiver, uint256 chainId) external view returns (uint256);

  /**
   * @notice Deposit assets with chain-specific soft cap bypass consideration
   * @dev This function is only callable by the AssetManager
   * @param assets The amount of assets to deposit
   * @param receiver The address receiving the shares
   * @param chainId The chain ID where the deposit originates
   * @return shares The amount of shares minted
   */
  function depositForChainId(uint256 assets, address receiver, uint256 chainId) external returns (uint256 shares);
}
