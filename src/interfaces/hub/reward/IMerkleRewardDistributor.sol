// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor } from './IRewardDistributor.sol';

/**
 * @title IMerkleRewardDistributorStorageV1
 * @notice Interface definition for the MerkleRewradDistributorStorageV1
 */
interface IMerkleRewardDistributorStorageV1 {
  struct StageResponse {
    uint256 amount;
    bytes32 root;
  }

  /**
   * @notice Returns the stage info of specific distribution for the EOLVault and reward token.
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param stageNum The stage number
   */
  function stage(address eolVault, address reward, uint256 stageNum) external view returns (StageResponse memory);
}

/**
 * @title IMerkleRewardDistributor
 * @notice Interface for the Merkle based reward distributor
 */
interface IMerkleRewardDistributor is IRewardDistributor, IMerkleRewardDistributorStorageV1 {
  struct RewardMerkleMetadata {
    uint256 stage;
    uint256 amount;
    bytes32[] proof;
  }

  event Claimed(
    address indexed eolVault, address indexed account, address indexed receiver, address reward, uint256 amount
  );

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
   * @notice Makes a leaf hash that expected to be used in the Merkle tree.
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param stage_ The stage number
   * @param account The account address
   * @param amount The reward amount
   * @return leaf The leaf hash
   */
  function encodeLeaf(address eolVault, address reward, uint256 stage_, address account, uint256 amount)
    external
    pure
    returns (bytes32 leaf);

  /**
   * @notice Checks if the account can claim.
   * @param eolVault The EOL Vault address
   * @param account The account address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claimable(address eolVault, address account, address reward, RewardMerkleMetadata memory metadata)
    external
    view
    returns (bool);

  /**
   * @notice Returns the amount of claimable rewards for the account.
   * @param eolVault The EOL Vault address
   * @param account The account address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claimableAmount(address eolVault, address account, address reward, RewardMerkleMetadata memory metadata)
    external
    view
    returns (uint256);

  /**
   * @notice Claims all of the rewards for the specified vault and reward, sending them to the receiver.
   * @param eolVault The EOL Vault address
   * @param receiver The receiver address
   * @param reward The reward token address
   * @param metadata The encoded metadata
   */
  function claim(address eolVault, address receiver, address reward, RewardMerkleMetadata memory metadata) external;
}
