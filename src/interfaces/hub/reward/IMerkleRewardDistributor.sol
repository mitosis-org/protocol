// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, IRewardDistributorStorage, DistributionType } from './IRewardDistributor.sol';

/**
 * @title IMerkleRewardDistributorStorageV1
 * @author Manythings Pte. Ltd.
 * @dev Interface for the storage of Merkle-based reward distributors (version 1).
 */
interface IMerkleRewardDistributorStorageV1 is IRewardDistributorStorage {
  /**
   * @dev Struct representing the response for a stage query.
   * @param amount The total amount of rewards for the stage.
   * @param root The Merkle root for the stage.
   */
  struct StageResponse {
    uint256 amount;
    bytes32 root;
  }

  /**
   * @notice Retrieves the stage information for a specific EOL vault, reward, and stage.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param stage_ The stage number.
   * @return A StageResponse struct containing the stage information.
   */
  function stage(address eolVault, address reward, uint256 stage_) external view returns (StageResponse memory);
}

/**
 * @title IMerkleRewardDistributor
 * @author Manythings Pte. Ltd.
 * @dev Interface for Merkle-based reward distributors, extending IRewardDistributor and IMerkleRewardDistributorStorageV1.
 */
interface IMerkleRewardDistributor is IRewardDistributor, IMerkleRewardDistributorStorageV1 {
  /**
   * @notice Error thrown when attempting to claim an already claimed reward.
   */
  error IMerkleRewardDistributor__AlreadyClaimed();

  /**
   * @notice Error thrown when an invalid Merkle proof is provided.
   */
  error IMerkleRewardDistributor__InvalidProof();

  /**
   * @notice Error thrown when an invalid amount is provided for claim.
   */
  error IMerkleRewardDistributor__InvalidAmount();

  /**
   * @notice Encodes metadata for a Merkle claim.
   * @param eolVault The address of the EOL vault.
   * @param stage_ The stage of the distribution.
   * @param amount The amount of reward to claim.
   * @param proof The Merkle proof for the claim.
   * @return The encoded metadata.
   */
  function encodeMetadata(address eolVault, uint256 stage_, uint256 amount, bytes32[] calldata proof)
    external
    pure
    returns (bytes memory);

  /**
   * @notice Encodes a leaf for the Merkle tree.
   * @param eolVault The address of the EOL vault.
   * @param reward The address of the reward token.
   * @param stage_ The stage of the distribution.
   * @param account The address of the account eligible for the reward.
   * @param amount The amount of reward.
   * @return leaf The encoded leaf.
   */
  function encodeLeaf(address eolVault, address reward, uint256 stage_, address account, uint256 amount)
    external
    pure
    returns (bytes32 leaf);
}
