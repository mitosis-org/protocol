// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { BaseHandler } from '../../src/hub/reward/BaseHandler.sol';
import { IRewardHandler } from '../../src/interfaces/hub/reward/IRewardHandler.sol';

contract MockRewardHandler is IRewardHandler, BaseHandler {
  constructor() BaseHandler(HandlerType.Middleware, DistributionType.Unspecified, 'Mock Reward Handler') { }

  function _isDispatchable(address) internal pure override returns (bool) {
    return true;
  }

  function _handleReward(address, address reward, uint256 amount, bytes calldata) internal override {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);
  }
}
