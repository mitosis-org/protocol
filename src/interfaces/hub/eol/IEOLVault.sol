// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC4626TWABSnapshots } from '../../twab/IERC4626TWABSnapshots.sol';

interface IEOLVaultStorageV1 {
  event RewardManagerSet(address rewardManager);
  event AssetManagerSet(address assetManager);

  function rewardManager() external view returns (address);
  function assetManager() external view returns (address);
}

interface IEOLVault is IEOLVaultStorageV1, IERC4626TWABSnapshots {
  event PendingAssetsClaimed(address indexed receiver, uint256 assets);
  event YieldSettled(uint256 yield);
  event LossSettled(uint256 loss);

  function claim(uint256 assets, address receiver) external returns (uint256);
  function settleYield(uint256 yield) external;
  function settleLoss(uint256 loss) external;
}
