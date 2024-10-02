// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from '../../src/interfaces/hub/core/IAssetManager.sol';

contract MockAssetManager is IAssetManager {
  address internal _optOutQueue;

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external { }
  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address branchAsset_) { }
  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external { }
  function deposit(uint256 chainId, address branchAsset_, address to, uint256 amount) external { }
  function depositWithOptIn(uint256 chainId, address branchAsset_, address to, address eolVault, uint256 amount)
    external
  { }
  function entrypoint() external view returns (address entrypoint_) { }
  function eolInitialized(uint256 chainId, address eolVault) external view returns (bool) { }
  function eolAlloc(address eolVault) external view returns (uint256 eolVaultAllocation) { }
  function eolIdle(address eolVault) external view returns (uint256 eolVaultIdleBalance) { }
  function strategist(address eolVault) external view returns (address) { }

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address hubAsset_) { }
  function initializeAsset(uint256 chainId, address hubAsset_) external { }
  function initializeEOL(uint256 chainId, address eolVault) external { }

  function optOutQueue() external view returns (address optOutQueue_) {
    return _optOutQueue;
  }

  function setOptOutQueue(address optOutQueue_) external {
    _optOutQueue = optOutQueue_;
  }

  function redeem(uint256 chainId, address branchAsset_, address to, uint256 amount) external { }
  function rewardRouter() external view returns (address rewardRouter_) { }
  function settleExtraRewards(uint256 chainId, address eolVault, address reward, uint256 amount) external { }
  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external { }
  function settleYield(uint256 chainId, address eolVault, uint256 amount) external { }
  function setAssetPair(address hubAsset_, uint256 branchChainId, address branchAsset_) external { }
  function setEntrypoint(address entrypoint_) external { }
  function setRewardRouter(address rewardRouter_) external { }
  function setStrategist(address eolVault, address) external { }
}
