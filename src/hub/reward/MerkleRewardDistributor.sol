// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { MerkleProof } from '@oz-v5/utils/cryptography/MerkleProof.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IRewardDistributor } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { LibDistributorRewardMetadata, RewardMerkleMetadata } from './LibDistributorRewardMetadata.sol';
import { MerkleRewardDistributorStorageV1 } from './MerkleRewardDistributorStorageV1.sol';

contract MerkleRewardDistributor is IRewardDistributor, Ownable2StepUpgradeable, MerkleRewardDistributorStorageV1 {
  using SafeERC20 for IERC20;
  using MerkleProof for bytes32[];
  using LibDistributorRewardMetadata for bytes;
  using LibDistributorRewardMetadata for RewardMerkleMetadata;

  error MerkleRewardDistributor__AlreadyClaimed();
  error MerkleRewardDistributor__InvalidProof();

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  /// @dev Checks if the account can claim.
  function claimable(address account, address reward, bytes calldata metadata) external view returns (bool) {
    return _claimable(account, reward, metadata.decodeRewardMerkleMetadata());
  }

  /// @dev Returns the amount of claimable rewards for the account.
  function claimableAmount(address account, address reward, bytes calldata metadata) external view returns (uint256) {
    return _claimableAmount(account, reward, metadata.decodeRewardMerkleMetadata());
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  /// @dev Claims all of the rewards for the specified vault and reward.
  function claim(address reward, bytes calldata metadata) external {
    _claim(_msgSender(), reward, metadata.decodeRewardMerkleMetadata());
  }

  /// @dev Claims all of the rewards for the specified vault and reward, sending them to the receiver.
  function claim(address receiver, address reward, bytes calldata metadata) external {
    _claim(receiver, reward, metadata.decodeRewardMerkleMetadata());
  }

  /// @dev Claims a specific amount of rewards for the specified vault and reward.
  /// param `amount` will be ignored.
  function claim(address reward, uint256, bytes calldata metadata) external {
    _claim(_msgSender(), reward, metadata.decodeRewardMerkleMetadata());
  }

  /// @dev Claims a specific amount of rewards for the specified vault and reward, sending them to the receiver.
  /// param `amount` will be ignored.
  function claim(address receiver, address reward, uint256, bytes calldata metadata) external {
    _claim(receiver, reward, metadata.decodeRewardMerkleMetadata());
  }

  /// @dev Handles the distribution of rewards for the specified vault and reward.
  /// This method can only be called by the RewardManager.
  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external {
    StorageV1 storage $ = _getStorageV1();
    _assertOnlyRewardManager($);

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);

    (uint256 stageNum, bytes32 root) = abi.decode(metadata, (uint256, bytes32));
    Stage storage stage = $.stages[eolVault][reward][stageNum];
    stage.amount = amount;
    stage.root = root;

    // TODO(eddy): find out what is the proper values to input
    // eligibleRewardAsset = eolVault
    // batchTimestamp = nextStage
    emit RewardHandled(eolVault, reward, amount, stageNum, $.distributionType, metadata);
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function setRewardConfigurator(address rewardConfigurator_) external onlyOwner {
    return _setRewardConfigurator(_getStorageV1(), rewardConfigurator_);
  }

  function setRewardManager(address rewardManager_) external onlyOwner {
    return _setRewardManager(_getStorageV1(), rewardManager_);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _claimable(address account, address reward, RewardMerkleMetadata memory metadata)
    internal
    view
    returns (bool)
  {
    StorageV1 storage $ = _getStorageV1();
    Stage storage stage = _stage($, metadata.eolVault, reward, metadata.stage);

    bytes32 leaf = _leaf(metadata.eolVault, reward, metadata.stage, account, metadata.amount);

    return !stage.claimed[account] && metadata.proof.verify(stage.root, leaf);
  }

  function _claimableAmount(address account, address reward, RewardMerkleMetadata memory metadata)
    internal
    view
    returns (uint256)
  {
    return _claimable(account, reward, metadata) ? metadata.amount : 0;
  }

  function _claim(address account, address reward, RewardMerkleMetadata memory metadata) internal {
    StorageV1 storage $ = _getStorageV1();
    Stage storage stage = _stage($, metadata.eolVault, reward, metadata.stage);
    require(!stage.claimed[account], MerkleRewardDistributor__AlreadyClaimed());

    bytes32 leaf = _leaf(metadata.eolVault, reward, metadata.stage, account, metadata.amount);
    require(metadata.proof.verify(stage.root, leaf), MerkleRewardDistributor__InvalidProof());

    IERC20(reward).safeTransfer(account, metadata.amount);
  }

  function _leaf(address eolVault, address reward, uint256 stage, address account, uint256 amount)
    internal
    pure
    returns (bytes32 leaf)
  {
    return keccak256(abi.encodePacked(eolVault, reward, stage, account, amount));
  }
}
