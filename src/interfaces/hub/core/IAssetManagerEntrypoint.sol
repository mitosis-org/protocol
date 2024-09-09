// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IAssetManagerEntrypoint {
  function initializeAsset(uint256 chainId, address branchAsset) external;

  function initializeEOL(uint256 chainId, address eolVault, address branchAsset) external;

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external;
}
