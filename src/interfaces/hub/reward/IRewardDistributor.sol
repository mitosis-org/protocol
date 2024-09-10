// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

enum DistributionType {
  Unspecified,
  MerkleProof,
  TWAB
}

interface IRewardDistributorStorage {
  function distributionType() external view returns (DistributionType);

  function description() external view returns (string memory);
}

interface IRewardDistributor is IRewardDistributorStorage {
  // metadata: See the `src/hub/eol/LibDistributorRewardMetadata`.

  function claimable(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (bool);

  function claimableAmount(address account, address eolVault, address asset, bytes calldata metadata)
    external
    view
    returns (uint256);

  function claim(address eolVault, address reward, bytes calldata metadata) external;

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external;

  function handleReward(address eolVault, address asset, uint256 amount, bytes calldata metadata) external;

  function setRewardManager(address rewardManager_) external;
}
