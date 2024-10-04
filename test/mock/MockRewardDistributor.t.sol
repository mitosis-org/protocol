// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { BaseHandler } from '../../src/hub/reward/BaseHandler.sol';
import { IRewardDistributor } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockRewardDistributor is IRewardDistributor, BaseHandler {
  constructor() BaseHandler(HandlerType.Endpoint, DistributionType.Unspecified, 'Mock Reward Distributor') { }

  function claimable(address, address, bytes memory) external pure returns (bool) {
    return true;
  }

  function claimableAmount(address, address, bytes calldata) external pure returns (uint256) {
    return 0;
  }

  function rewardedAts(address, uint256, uint256) external view returns (uint48[] memory result) { }

  function rewardedAtsLength(address, address) external pure returns (uint256) {
    return 0;
  }

  function claim(address, bytes calldata) external { }

  function claim(address, address, bytes calldata) external { }

  function claim(address, address, uint256, bytes calldata) external { }

  function claim(address, uint256, bytes calldata) external { }

  // ================== NOTE: BaseHandler implementation ================== //

  function _isDispatchable(address) internal pure override returns (bool) {
    return true;
  }

  function _handleReward(address, address reward, uint256 amount, bytes calldata) internal override {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);
  }
}
