// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC4626TWABSnapshots } from '../../../twab/IERC4626TWABSnapshots.sol';

/**
 * @title IEOLVaultStorageV1
 * @dev Interface for the storage of EOLVault version 1.
 */
interface IEOLVaultStorageV1 {
  /**
   * @notice Emitted when the asset manager is set.
   * @param assetManager_ The address of the new asset manager.
   */
  event AssetManagerSet(address assetManager_);

  /**
   * @notice Returns the address of the current asset manager.
   */
  function assetManager() external view returns (address);
}

/**
 * @title IEOLVault
 * @dev Interface for the EOLVault, combining ERC4626 functionality with TWAB snapshots.
 */
interface IEOLVault is IERC4626TWABSnapshots, IEOLVaultStorageV1 { }
