// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from '../../src/interfaces/hub/reward/IRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockDistributor is IRewardDistributor {
  DistributionType _distributionType;

  constructor(DistributionType distributionType_) {
    _distributionType = distributionType_;
  }

  function distributionType() external view returns (DistributionType) {
    return _distributionType;
  }

  function description() external pure returns (string memory) {
    return 'MockDistributor';
  }

  function rewardConfigurator() external pure returns (IRewardConfigurator) {
    return IRewardConfigurator(address(0));
  }

  function claimable(address, address, address, bytes memory) external pure returns (bool) {
    return true;
  }

  function claimableAmount(address, address, address, bytes calldata) external view returns (uint256) {
    return 0;
  }

  function claim(address eolVault, address reward, bytes calldata metadata) external { }

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external { }

  function handleReward(address, address, uint256, bytes memory) external pure {
    return;
  }

  function setRewardManager(address rewardManager_) external { }
}
