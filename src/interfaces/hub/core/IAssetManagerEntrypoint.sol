// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from './IAssetManager.sol';

interface IAssetManagerEntrypoint {
  function assetManager() external view returns (IAssetManager assetManger_);

  function branchDomain(uint256 chainId) external view returns (uint32);

  function branchVault(uint256 chainId) external view returns (address);

  function branchEntrypointAddr(uint256 chainId) external view returns (address);

  function initializeAsset(uint256 chainId, address branchAsset) external;

  function initializeEOL(uint256 chainId, address eolVault, address branchAsset) external;

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;
}
