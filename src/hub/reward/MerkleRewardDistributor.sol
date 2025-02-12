// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { MerkleProof } from '@oz-v5/utils/cryptography/MerkleProof.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { StdError } from '../../lib/StdError.sol';
import { MerkleRewardDistributorStorageV1 } from './MerkleRewardDistributorStorageV1.sol';

contract MerkleRewardDistributor is
  IMerkleRewardDistributor,
  MerkleRewardDistributorStorageV1,
  AccessControlEnumerableUpgradeable
{
  using SafeERC20 for IERC20;
  using MerkleProof for bytes32[];

  /// @notice Role for manager (keccak256("MANAGER_ROLE"))
  bytes32 public constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address admin, address treasury_) public initializer {
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

    _setTreasury(_getStorageV1(), treasury_);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function lastStage() external view returns (uint256) {
    return _getStorageV1().lastStage;
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function root(uint256 stage_) external view returns (bytes32) {
    return _stage(_getStorageV1(), stage_).root;
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function rewardInfo(uint256 stage_) external view returns (address[] memory, uint256[] memory) {
    Stage storage s = _stage(_getStorageV1(), stage_);
    return (s.rewards, s.amounts);
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function treasury() external view returns (ITreasury) {
    return _getStorageV1().treasury;
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function encodeLeaf(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external pure returns (bytes32 leaf) {
    return _leaf(receiver, stage, matrixVault, rewards, amounts);
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimable(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) external view returns (bool) {
    return _claimable(receiver, stage, matrixVault, rewards, amounts, proof);
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claim(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) public {
    _claim(receiver, stage, matrixVault, rewards, amounts, proof);
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimMultiple(
    address receiver,
    uint256 stage,
    address[] calldata matrixVaults,
    address[][] calldata rewards,
    uint256[][] calldata amounts,
    bytes32[][] calldata proofs
  ) public {
    require(matrixVaults.length == rewards.length, StdError.InvalidParameter('rewards.length'));
    require(matrixVaults.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    require(matrixVaults.length == proofs.length, StdError.InvalidParameter('proofs.length'));

    for (uint256 i = 0; i < matrixVaults.length; i++) {
      claim(receiver, stage, matrixVaults[i], rewards[i], amounts[i], proofs[i]);
    }
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimBatch(
    address receiver,
    uint256[] calldata stages,
    address[][] calldata matrixVaults,
    address[][][] calldata rewards,
    uint256[][][] calldata amounts,
    bytes32[][][] calldata proofs
  ) public {
    require(stages.length == matrixVaults.length, StdError.InvalidParameter('matrixVaults.length'));
    require(stages.length == rewards.length, StdError.InvalidParameter('rewards.length'));
    require(stages.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    require(stages.length == proofs.length, StdError.InvalidParameter('proofs.length'));

    for (uint256 i = 0; i < stages.length; i++) {
      claimMultiple(receiver, stages[i], matrixVaults[i], rewards[i], amounts[i], proofs[i]);
    }
  }

  // ============================ NOTE: MANAGER FUNCTIONS ============================ //

  function fetchRewards(uint256 stage, uint256 nonce, address matrixVault, address reward, uint256 amount)
    external
    onlyRole(MANAGER_ROLE)
  {
    StorageV1 storage $ = _getStorageV1();

    require(stage == $.lastStage, IMerkleRewardDistributor__NotCurrentStage(stage));
    require(nonce == _stage($, stage).nonce, IMerkleRewardDistributor__InvalidStageNonce(stage, nonce));

    _fetchRewards($, stage, matrixVault, reward, amount);
  }

  function fetchRewardsMultiple(
    uint256 stage,
    uint256 nonce,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external onlyRole(MANAGER_ROLE) {
    StorageV1 storage $ = _getStorageV1();

    require(stage == $.lastStage, IMerkleRewardDistributor__NotCurrentStage(stage));
    require(nonce == _stage($, stage).nonce, IMerkleRewardDistributor__InvalidStageNonce(stage, nonce));

    for (uint256 i = 0; i < rewards.length; i++) {
      _fetchRewards($, stage, matrixVault, rewards[i], amounts[i]);
    }
  }

  function fetchRewardsBatch(
    uint256 stage,
    uint256 nonce,
    address[] calldata matrixVaults,
    address[][] calldata rewards,
    uint256[][] calldata amounts
  ) external onlyRole(MANAGER_ROLE) {
    StorageV1 storage $ = _getStorageV1();

    require(stage == $.lastStage, IMerkleRewardDistributor__NotCurrentStage(stage));
    require(nonce == _stage($, stage).nonce, IMerkleRewardDistributor__InvalidStageNonce(stage, nonce));
    require(matrixVaults.length == rewards.length, StdError.InvalidParameter('rewards.length'));

    for (uint256 i = 0; i < matrixVaults.length; i++) {
      for (uint256 j = 0; j < rewards[i].length; j++) {
        _fetchRewards($, stage, matrixVaults[i], rewards[i][j], amounts[i][j]);
      }
    }
  }

  function addStage(
    bytes32 merkleRoot,
    uint256 stage,
    uint256 nonce,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external onlyRole(MANAGER_ROLE) returns (uint256 merkleStage) {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, stage);

    require(stage == $.lastStage, IMerkleRewardDistributor__NotCurrentStage(stage));
    require(nonce == s.nonce, IMerkleRewardDistributor__InvalidStageNonce(stage, nonce));
    require(rewards.length == amounts.length, StdError.InvalidParameter('amounts.length'));

    for (uint256 i = 0; i < rewards.length; i++) {
      address reward = rewards[i];
      uint256 amount = amounts[i];
      require(_availableRewardAmount($, reward) >= amount, IMerkleRewardDistributor__InvalidAmount());
      $.reservedRewardAmounts[reward] += amount;
    }

    _addStage($, merkleRoot, rewards, amounts);

    return merkleStage;
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _setTreasury(StorageV1 storage $, address treasury_) internal {
    require(treasury_.code.length > 0, StdError.InvalidAddress('Treasury'));
    $.treasury = ITreasury(treasury_);
  }

  function _fetchRewards(StorageV1 storage $, uint256 stage, address matrixVault, address reward, uint256 amount)
    internal
  {
    $.treasury.dispatch(matrixVault, reward, amount, address(this));

    Stage storage s = _stage($, stage);
    emit RewardsFetched(stage, s.nonce, matrixVault, reward, amount);
    s.nonce++;
  }

  function _addStage(StorageV1 storage $, bytes32 root_, address[] calldata rewards, uint256[] calldata amounts)
    internal
    onlyRole(MANAGER_ROLE)
    returns (uint256 stage)
  {
    $.lastStage += 1;
    Stage storage s = _stage($, $.lastStage);
    s.root = root_;
    s.rewards = rewards;
    s.amounts = amounts;

    emit StageAdded($.lastStage, root_, rewards, amounts);

    return $.lastStage;
  }

  function _stage(StorageV1 storage $, uint256 stage) internal view returns (Stage storage) {
    return $.stages[stage];
  }

  function _claimable(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) internal view returns (bool) {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, stage);

    bytes32 leaf = _leaf(receiver, stage, matrixVault, rewards, amounts);

    return !s.claimed[receiver][matrixVault] && proof.verify(s.root, leaf);
  }

  function _claim(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) internal {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, stage);

    require(!s.claimed[receiver][matrixVault], IMerkleRewardDistributor__AlreadyClaimed());
    s.claimed[receiver][matrixVault] = true;

    bytes32 leaf = _leaf(receiver, stage, matrixVault, rewards, amounts);
    require(proof.verify(s.root, leaf), IMerkleRewardDistributor__InvalidProof());

    require(rewards.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    for (uint256 i = 0; i < rewards.length; i++) {
      address reward = rewards[i];
      uint256 amount = amounts[i];
      IERC20(reward).safeTransfer(receiver, amount);
      $.reservedRewardAmounts[reward] -= amount;
    }

    emit Claimed(receiver, stage, matrixVault, rewards, amounts);
  }

  function _availableRewardAmount(StorageV1 storage $, address reward) internal view returns (uint256) {
    return IERC20(reward).balanceOf(address(this)) - $.reservedRewardAmounts[reward];
  }

  function _leaf(
    address receiver,
    uint256 stage,
    address matrixVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) internal pure returns (bytes32 leaf) {
    // double-hashing to prevent second preimage attacks:
    // https://flawed.net.nz/2018/02/21/attacking-merkle-trees-with-a-second-preimage-attack/
    return keccak256(bytes.concat(keccak256(abi.encodePacked(receiver, stage, matrixVault, rewards, amounts))));
  }
}
