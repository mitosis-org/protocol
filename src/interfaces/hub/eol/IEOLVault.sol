// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626TwabSnapshots } from '../../twab/IERC4626TwabSnapshots.sol';

interface IEOLVaultStorageV1 {
  event AssetManagerSet(address assetManager);

  function assetManager() external view returns (address);
}

interface IEOLVault is IERC4626TwabSnapshots, IEOLVaultStorageV1 { }
