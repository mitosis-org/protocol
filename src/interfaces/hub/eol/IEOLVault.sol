// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC4626TWABSnapshots } from '../../twab/IERC4626TWABSnapshots.sol';

interface IEOLVaultStorageV1 {
  event AssetManagerSet(address assetManager);

  function assetManager() external view returns (address);
}

interface IEOLVault is IERC4626TWABSnapshots, IEOLVaultStorageV1 { }
