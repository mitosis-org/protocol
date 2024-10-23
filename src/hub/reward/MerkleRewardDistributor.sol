// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { MerkleProof } from '@oz-v5/utils/cryptography/MerkleProof.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { IRewardDistributor } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { StdError } from '../../lib/StdError.sol';
import { BaseHandler } from './BaseHandler.sol';
import { LibDistributorRewardMetadata, RewardMerkleMetadata } from './LibDistributorRewardMetadata.sol';
import { MerkleRewardDistributorStorageV1 } from './MerkleRewardDistributorStorageV1.sol';

contract MerkleRewardDistributor is
  BaseHandler,
  IMerkleRewardDistributor,
  MerkleRewardDistributorStorageV1,
  AccessControlEnumerableUpgradeable
{
  using SafeERC20 for IERC20;
  using MerkleProof for bytes32[];
  using LibDistributorRewardMetadata for bytes;
  using LibDistributorRewardMetadata for RewardMerkleMetadata;

  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() BaseHandler(HandlerType.Endpoint, DistributionType.Merkle, 'Merkle Reward Distributor') {
    _disableInitializers();
  }

  function initialize(address admin) public initializer {
    __BaseHandler_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(DISPATCHER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function encodeMetadata(uint256 stage_, uint256 amount, bytes32[] calldata proof)
    external
    pure
    returns (bytes memory)
  {
    return RewardMerkleMetadata({ stage: stage_, amount: amount, proof: proof }).encode();
  }

  /**
   * @inheritdoc IMerkleRewardDistributor
   */
  function encodeLeaf(address eolVault, address reward, uint256 stage_, address account, uint256 amount)
    external
    pure
    returns (bytes32 leaf)
  {
    return _leaf(eolVault, reward, stage_, account, amount);
  }

  /**
   * @inheritdoc IRewardDistributor
   */
  function claimable(address eolVault, address account, address reward, bytes calldata metadata)
    external
    view
    returns (bool)
  {
    return _claimable(eolVault, account, reward, metadata.decodeRewardMerkleMetadata());
  }

  /**
   * @inheritdoc IRewardDistributor
   */
  function claimableAmount(address eolVault, address account, address reward, bytes calldata metadata)
    external
    view
    returns (uint256)
  {
    return _claimableAmount(eolVault, account, reward, metadata.decodeRewardMerkleMetadata());
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  /**
   * @inheritdoc IRewardDistributor
   */
  function claim(address eolVault, address reward, bytes calldata metadata) external {
    claim(eolVault, _msgSender(), reward, metadata);
  }

  /**
   * @inheritdoc IRewardDistributor
   */
  function claim(address eolVault, address receiver, address reward, bytes calldata metadata) public {
    _claim(eolVault, _msgSender(), receiver, reward, metadata.decodeRewardMerkleMetadata());
  }

  /**
   * @inheritdoc IRewardDistributor
   */
  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    claim(eolVault, _msgSender(), reward, amount, metadata);
  }

  /**
   * @inheritdoc IRewardDistributor
   */
  function claim(address eolVault, address receiver, address reward, uint256 amount, bytes calldata metadata) public {
    RewardMerkleMetadata memory metadata_ = metadata.decodeRewardMerkleMetadata();
    require(metadata_.amount == amount, IMerkleRewardDistributor__InvalidAmount());

    _claim(eolVault, _msgSender(), receiver, reward, metadata_);
  }

  // ============================ NOTE: OVERRIDE FUNCTIONS ============================ //

  function _isDispatchable(address dispatcher) internal view override returns (bool) {
    return hasRole(DISPATCHER_ROLE, dispatcher);
  }

  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) internal override {
    StorageV1 storage $ = _getStorageV1();

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);

    (uint256 stageNum, bytes32 root) = abi.decode(metadata, (uint256, bytes32));
    Stage storage stage = $.stages[eolVault][reward][stageNum];
    stage.amount = amount;
    stage.root = root;

    emit RewardHandled(eolVault, reward, amount, distributionType(), metadata, bytes(''));
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _claimable(address eolVault, address account, address reward, RewardMerkleMetadata memory metadata)
    internal
    view
    returns (bool)
  {
    StorageV1 storage $ = _getStorageV1();
    Stage storage stage = _stage($, eolVault, reward, metadata.stage);

    bytes32 leaf = _leaf(eolVault, reward, metadata.stage, account, metadata.amount);

    return !stage.claimed[account] && metadata.proof.verify(stage.root, leaf);
  }

  function _claimableAmount(address eolVault, address account, address reward, RewardMerkleMetadata memory metadata)
    internal
    view
    returns (uint256)
  {
    return _claimable(eolVault, account, reward, metadata) ? metadata.amount : 0;
  }

  function _claim(
    address eolVault,
    address account,
    address receiver,
    address reward,
    RewardMerkleMetadata memory metadata
  ) internal {
    StorageV1 storage $ = _getStorageV1();
    Stage storage stage = _stage($, eolVault, reward, metadata.stage);

    require(!stage.claimed[account], IMerkleRewardDistributor__AlreadyClaimed());
    stage.claimed[account] = true;

    bytes32 leaf = _leaf(eolVault, reward, metadata.stage, account, metadata.amount);
    require(metadata.proof.verify(stage.root, leaf), IMerkleRewardDistributor__InvalidProof());

    IERC20(reward).safeTransfer(receiver, metadata.amount);
    emit Claimed(eolVault, account, receiver, reward, metadata.amount);
  }

  function _leaf(address eolVault, address reward, uint256 stage_, address account, uint256 amount)
    internal
    pure
    returns (bytes32 leaf)
  {
    return keccak256(abi.encodePacked(eolVault, reward, stage_, account, amount));
  }
}
