// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IRewardDistributor } from '../../interfaces/hub/core/IRewardDistributor.sol';
import { IRewardTreasury } from '../../interfaces/hub/core/IRewardTreasury.sol';
import { StdError } from '../../lib/StdError.sol';

// This is an example contract. This contract will be removed before the PR merge.
contract OnlyOwnerRewardDistributor is IRewardDistributor {
  address _owner;
  address _rewardTreasury;

  mapping(uint256 eolId => mapping(address asset => uint256 amount)) _rewards;

  constructor(address owner_, address rewardTreasury_) {
    _owner = owner_;
    _rewardTreasury = rewardTreasury_;
  }

  function dispatch(uint256 eolId, address asset, uint256 amount, uint48) external {
    if (msg.sender != _rewardTreasury) revert StdError.Unauthorized();
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    _rewards[eolId][asset] += amount;
  }

  function claim(uint256 eolId, address asset, uint48) external {
    if (msg.sender != _owner) revert StdError.Unauthorized();

    uint256 amount = _rewards[eolId][asset];
    if (amount > 0) {
      _rewards[eolId][asset] = 0;
      IERC20(asset).transfer(_owner, amount);
    }
  }

  function claim(uint256, address, uint256, uint48, bytes32[] calldata) external pure {
    revert StdError.NotImplemented();
  }
}
