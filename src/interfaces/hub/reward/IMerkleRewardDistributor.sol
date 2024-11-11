// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor } from './IRewardDistributor.sol';

/**
 * @title IMerkleRewardDistributor
 * @notice Interface for the Merkle based reward distributor
 */
interface IMerkleRewardDistributor {
  event StageAdded(uint256 indexed stage, bytes32 root);

  event Claimed(
    address indexed receiver, uint256 indexed stage, address indexed eolVault, address[] rewards, uint256[] amounts
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

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  /**
   * @notice Returns the last stage. If no stage exists, it returns 0.
   */
  function lastStage() external view returns (uint256);

  /**
   * @notice Returns the root hash of the specified stage. If the stage does not exist, it returns 0.
   */
  function root(uint256 stage_) external view returns (bytes32);

  /**
   * @notice Makes a leaf hash that expected to be used in the merkle tree.
   * @param stage The stage number.
   * @param receiver The receiver address.
   * @param eolVault The EOL Vault address.
   * @param rewards The reward token addresses.
   * @param amounts The reward amounts.
   */
  function encodeLeaf(
    address receiver,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external pure returns (bytes32 leaf);

  /**
   * @notice Checks if the account can claim the rewards for the specified eolVault in the specified stage.
   * @param receiver The receiver address.
   * @param stage The stage number.
   * @param eolVault The EOL Vault address.
   * @param rewards The reward token addresses.
   * @param amounts The reward amounts.
   * @param proof The merkle proof.
   */
  function claimable(
    address receiver,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) external view returns (bool);

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  /**
   * @notice Claims rewards for the specified eolVault in the specified stage.
   */
  function claim(
    address receiver,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) external;

  /**
   * @notice Claims rewards for the multiple eolVaults in the specified stage.
   */
  function claimMultiple(
    address receiver,
    uint256 stage,
    address[] calldata eolVaults,
    address[][] calldata rewards,
    uint256[][] calldata amounts,
    bytes32[][] calldata proofs
  ) external;

  /**
   * @notice Claims rewards for the multiple eolVaults in the multiple stages.
   */
  function claimBatch(
    address receiver,
    uint256[] calldata stages,
    address[][] calldata eolVaults,
    address[][][] calldata rewards,
    uint256[][][] calldata amounts,
    bytes32[][][] calldata proofs
  ) external;

  // ============================ NOTE: MANAGER FUNCTIONS ============================ //

  /**
   * @notice Adds a new stage with the specified root hash.
   * @param root_ The root hash of the merkle tree.
   * @return stage The stage number of the added root hash.
   */
  function addStage(bytes32 root_) external returns (uint256 stage);
}
