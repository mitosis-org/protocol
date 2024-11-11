// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { MerkleProof } from '@oz-v5/utils/cryptography/MerkleProof.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { IRewardDistributor } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { StdError } from '../../lib/StdError.sol';
import { MerkleRewardDistributorStorageV1 } from './MerkleRewardDistributorStorageV1.sol';

contract MerkleRewardDistributor is
  IMerkleRewardDistributor,
  MerkleRewardDistributorStorageV1,
  AccessControlEnumerableUpgradeable
{
  using SafeERC20 for IERC20;
  using MerkleProof for bytes32[];

  bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address admin) public initializer {
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
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
  function encodeLeaf(
    address account,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external pure returns (bytes32 leaf) {
    return _leaf(account, stage, eolVault, rewards, amounts);
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimable(
    address account,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) external view returns (bool) {
    return _claimable(account, stage, eolVault, rewards, amounts, proof);
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claim(
    address receiver,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) public {
    _claim(_msgSender(), receiver, stage, eolVault, rewards, amounts, proof);
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimMultiple(
    address receiver,
    uint256 stage,
    address[] calldata eolVaults,
    address[][] calldata rewards,
    uint256[][] calldata amounts,
    bytes32[][] calldata proofs
  ) public {
    require(eolVaults.length == rewards.length, StdError.InvalidParameter('rewards.length'));
    require(eolVaults.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    require(eolVaults.length == proofs.length, StdError.InvalidParameter('proofs.length'));

    for (uint256 i = 0; i < eolVaults.length; i++) {
      claim(receiver, stage, eolVaults[i], rewards[i], amounts[i], proofs[i]);
    }
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function claimBatch(
    address receiver,
    uint256[] calldata stages,
    address[][] calldata eolVaults,
    address[][][] calldata rewards,
    uint256[][][] calldata amounts,
    bytes32[][][] calldata proofs
  ) public {
    require(stages.length == eolVaults.length, StdError.InvalidParameter('eolVaults.length'));
    require(stages.length == rewards.length, StdError.InvalidParameter('rewards.length'));
    require(stages.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    require(stages.length == proofs.length, StdError.InvalidParameter('proofs.length'));

    for (uint256 i = 0; i < stages.length; i++) {
      claimMultiple(receiver, stages[i], eolVaults[i], rewards[i], amounts[i], proofs[i]);
    }
  }

  // ============================ NOTE: MANAGER FUNCTIONS ============================ //

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function addStage(bytes32 root_) external onlyRole(MANAGER_ROLE) returns (uint256 stage) {
    StorageV1 storage $ = _getStorageV1();

    $.lastStage += 1;
    Stage storage s = $.stages[$.lastStage];
    s.root = root_;

    emit StageAdded($.lastStage, root_);

    return $.lastStage;
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _stage(StorageV1 storage $, uint256 stage) internal view returns (Stage storage) {
    return $.stages[stage];
  }

  function _claimable(
    address account,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) internal view returns (bool) {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, stage);

    bytes32 leaf = _leaf(account, stage, eolVault, rewards, amounts);

    return !s.claimed[account][eolVault] && proof.verify(s.root, leaf);
  }

  function _claim(
    address account,
    address receiver,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts,
    bytes32[] calldata proof
  ) internal {
    StorageV1 storage $ = _getStorageV1();
    Stage storage s = _stage($, stage);

    require(!s.claimed[account][eolVault], IMerkleRewardDistributor__AlreadyClaimed());
    s.claimed[account][eolVault] = true;

    bytes32 leaf = _leaf(account, stage, eolVault, rewards, amounts);
    require(proof.verify(s.root, leaf), IMerkleRewardDistributor__InvalidProof());

    require(rewards.length == amounts.length, StdError.InvalidParameter('amounts.length'));
    for (uint256 i = 0; i < rewards.length; i++) {
      IERC20(rewards[i]).safeTransfer(receiver, amounts[i]);
    }

    emit Claimed(account, receiver, stage, eolVault, rewards, amounts);
  }

  function _leaf(
    address account,
    uint256 stage,
    address eolVault,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) internal pure returns (bytes32 leaf) {
    // double-hashing to prevent second preimage attacks:
    // https://flawed.net.nz/2018/02/21/attacking-merkle-trees-with-a-second-preimage-attack/
    return keccak256(bytes.concat(keccak256(abi.encode(account, stage, eolVault, rewards, amounts))));
  }
}
