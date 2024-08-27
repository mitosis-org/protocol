// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Time } from '@oz-v5/utils/types/Time.sol';
import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IRewardDistributor } from '../../interfaces/hub/core/IRewardDistributor.sol';
import { IRewardTreasury } from '../../interfaces/hub/core/IRewardTreasury.sol';
import { StdError } from '../../lib/StdError.sol';

// This is an example contract. This contract will be removed before the PR merge.
contract OnlyOwnerRewardDistributor is IRewardDistributor {
  address _owner;
  address _rewardTreasury;

  mapping(uint256 eolId => mapping(address asset => BatchStorage batchStorage)) _batchStorages;

  constructor(address owner_, address rewardTreasury_) {
    _owner = owner_;
    _rewardTreasury = rewardTreasury_;
  }

  function nextBatch(uint256 eolId, address asset) external returns (uint256) {
    if (msg.sender != _owner) revert StdError.Unauthorized();
    BatchStorage storage batchStorage = _batchStorages[eolId][asset];

    if (batchStorage.currentBatchId > 0) {
      batchStorage.batches[batchStorage.currentBatchId].endedAt = Time.timestamp();
    }

    uint256 nextBatchId = ++batchStorage.currentBatchId;
    batchStorage.batches[nextBatchId].startedAt = Time.timestamp();

    return nextBatchId;
  }

  function receiveReward(uint256 eolId, address asset, uint256 amount, uint48) external {
    if (msg.sender != _rewardTreasury) revert StdError.Unauthorized();

    BatchStorage storage batchStorage = _batchStorages[eolId][asset];
    if (batchStorage.currentBatchId == 0) revert('batchId not initialized');

    IERC20(asset).transferFrom(msg.sender, address(this), amount);

    batchStorage.batches[batchStorage.currentBatchId].totalReward += amount;
  }

  function claim(uint256 eolId, address asset, uint256 batchId) external {
    claim(eolId, asset, batchId, _batchStorages[eolId][asset].batches[batchId].totalReward);
  }

  function claim(uint256 eolId, address asset, uint256 batchId, uint256 amountsClaimed) public {
    if (msg.sender != _owner) revert StdError.Unauthorized();

    BatchStorage storage batchStorage = _batchStorages[eolId][asset];
    Batch storage batch = batchStorage.batches[batchId];

    uint256 amount = batch.totalReward;
    if (amount < amountsClaimed) revert('not enough');

    batch.totalReward -= amountsClaimed;
    IERC20(asset).transfer(_owner, amount);
  }

  function claim(uint256, address, uint256, bytes32[] calldata) external pure {
    revert StdError.NotImplemented();
  }

  function claim(uint256, address, uint256, uint256, bytes32[] calldata) external pure {
    revert StdError.NotImplemented();
  }
}
