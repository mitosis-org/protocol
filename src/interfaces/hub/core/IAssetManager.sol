// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAssetManager {
  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external;

  function allocateEOL(uint256 chainId, uint256 eolId, uint256 amount) external;

  function deallocateEOL(uint256 eolId, uint256 amount) external;

  function settleYield(uint256 chainId, uint256 eolId, uint256 amount) external;

  function settleLoss(uint256 chainId, uint256 eolId, uint256 amount) external;

  function settleExtraRewards(uint256 chainId, uint256 eolId, address reward, uint256 amount) external;

  function initializeAsset(uint256 chainId, address hubAsset) external;

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external;

  function initializeEOL(uint256 chainId, uint256 eolId) external;
}
