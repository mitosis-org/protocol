// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from '../../src/interfaces/hub/core/IAssetManager.sol';

contract MockAssetManager is IAssetManager {
  address internal _entrypoint;
  address internal _reclaimQueue;
  address internal _treasury;

  function deposit(uint256 chainId_, address branchAsset_, address to_, uint256 amount_) external { }

  function depositWithSupplyMatrix(
    uint256 chainId_,
    address branchAsset_,
    address to_,
    address matrixVault_,
    uint256 amount_
  ) external { }

  function redeem(uint256 chainId_, address hubAsset_, address to_, uint256 amount_) external { }

  function allocateMatrix(uint256 chainId_, address matrixVault_, uint256 amount_) external { }

  function deallocateMatrix(uint256 chainId_, address matrixVault_, uint256 amount_) external { }

  function reserveMatrix(address matrixVault_, uint256 amount_) external { }

  function settleMatrixYield(uint256 chainId_, address matrixVault_, uint256 amount_) external { }

  function settleMatrixLoss(uint256 chainId_, address matrixVault_, uint256 amount_) external { }

  function settleMatrixExtraRewards(uint256 chainId_, address matrixVault_, address branchReward_, uint256 amount_)
    external
  { }

  function initializeAsset(uint256 chainId_, address hubAsset_) external { }

  function initializeMatrix(uint256 chainId_, address matrixVault_) external { }

  function setAssetPair(address hubAsset_, uint256 branchChainId_, address branchAsset_) external { }

  function setEntrypoint(address entrypoint_) external {
    _entrypoint = entrypoint_;
  }

  function setReclaimQueue(address reclaimQueue_) external {
    _reclaimQueue = reclaimQueue_;
  }

  function setTreasury(address treasury_) external {
    _treasury = treasury_;
  }

  function setStrategist(address matrixVault_, address strategist_) external { }

  function setHubAssetRedeemStatus(uint256 chainId, address hubAsset_, bool available) external { }

  function entrypoint() external view returns (address) {
    return _entrypoint;
  }

  function reclaimQueue() external view returns (address) {
    return _reclaimQueue;
  }

  function treasury() external view returns (address) {
    return _treasury;
  }

  function branchAsset(address hubAsset_, uint256 chainId_) external view returns (address) { }

  function hubAssetRedeemable(address hubAsset_, uint256 chainId) external view returns (bool) { }

  function hubAsset(uint256 chainId_, address branchAsset_) external view returns (address) { }

  function collateral(uint256 chainId_, address hubAsset_) external view returns (uint256) { }

  function matrixInitialized(uint256 chainId_, address matrixVault_) external view returns (bool) { }

  function matrixIdle(address matrixVault_) external view returns (uint256) { }

  function matrixAlloc(address matrixVault_) external view returns (uint256) { }

  function strategist(address matrixVault_) external view returns (address) { }
}
