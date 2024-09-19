// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from './IRewardConfigurator.sol';

enum DistributionType {
  Unspecified,
  MerkleProof,
  TWAB
}

interface IRewardDistributorStorage {
  event RewardConfiguratorSet(address indexed rewardConfigurator);

  /// @dev Returns the DistributionType.
  function distributionType() external view returns (DistributionType);

  /// @dev Returns the description.
  function description() external view returns (string memory);

  /// @dev Returns the set RewardManager.
  function rewardManager() external view returns (address);

  /// @dev Returns the set RewardConfigurator.
  function rewardConfigurator() external view returns (address);
}

interface IRewardDistributor is IRewardDistributorStorage {
  // metadata: See the `src/hub/eol/LibDistributorRewardMetadata`.RewardTWABMetadata

  /// @dev Checks if the account can claim.
  function claimable(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (bool);

  /// @dev Returns the amount of claimable rewards for the account.
  function claimableAmount(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (uint256);

  /// @dev Claims all of the rewards for the specified vault and reward.
  function claim(address eolVault, address reward, bytes calldata metadata) external;

  /// @dev Claims a specific amount of rewards for the specified vault and reward.
  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external;

  /// @dev Handles the distribution of rewards for the specified vault and asset.
  /// This method can only be called by the RewardManager.
  function handleReward(address eolVault, address asset, uint256 amount, bytes calldata metadata) external;

  /// @dev Sets the RewardManager address.
  function setRewardManager(address rewardManager_) external;

  /// @dev Sets the RewardConfigurator address.
  function setRewardConfigurator(address rewardConfigurator_) external;
}
