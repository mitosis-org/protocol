// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IRewardConfigurator } from '../../src/interfaces/hub/reward/IRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockDistributor is IRewardDistributor {
  DistributionType _distributionType;
  address _rewardConfigurator;

  constructor(DistributionType distributionType_, address rewardConfigurator_) {
    _distributionType = distributionType_;
    _rewardConfigurator = rewardConfigurator_;
  }

  function distributionType() external view returns (DistributionType) {
    return _distributionType;
  }

  function description() external pure returns (string memory) {
    return 'MockDistributor';
  }

  function rewardManager() external pure returns (address) {
    return address(0);
  }

  function rewardConfigurator() external view returns (address) {
    return _rewardConfigurator;
  }

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

  function handleReward(address, address reward, uint256 amount, bytes memory) external {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);
  }

  function setRewardManager(address rewardManager_) external { }

  function setRewardConfigurator(address rewardConfigurator_) external {
    _rewardConfigurator = rewardConfigurator_;
  }
}
