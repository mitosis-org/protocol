// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IRewardDistributor } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockRewardDistributor is IRewardDistributor {
  function handleReward(address, address reward, uint256 amount) external {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);
  }
}
