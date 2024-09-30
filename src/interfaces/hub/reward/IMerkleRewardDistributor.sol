// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, IRewardDistributorStorage, DistributionType } from './IRewardDistributor.sol';

interface IMerkleRewardDistributorStorageV1 is IRewardDistributorStorage {
  struct StageResponse {
    uint256 amount;
    bytes32 root;
  }

  function stage(address eolVault, address reward, uint256 stage_) external view returns (StageResponse memory);
}

interface IMerkleRewardDistributor is IRewardDistributor, IMerkleRewardDistributorStorageV1 {
  error IMerkleRewardDistributor__AlreadyClaimed();
  error IMerkleRewardDistributor__InvalidProof();

  function encodeMetadata(address eolVault, uint256 stage_, uint256 amount, bytes32[] calldata proof)
    external
    pure
    returns (bytes memory);

  function encodeLeaf(address eolVault, address reward, uint256 stage_, address account, uint256 amount)
    external
    pure
    returns (bytes32 leaf);
}
