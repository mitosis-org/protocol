// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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

  function rewardConfigurator() external view returns (IRewardConfigurator) {
    return IRewardConfigurator(_rewardConfigurator);
  }

  function claimable(address, address, address, bytes memory) external pure returns (bool) {
    return true;
  }

  function claimableAmount(address, address, address, bytes calldata) external pure returns (uint256) {
    return 0;
  }

  function claim(address eolVault, address reward, bytes calldata metadata) external { }

  function claim(address eolVault, address reward, uint256 amount, bytes calldata metadata) external { }

  function handleReward(address, address, uint256, bytes memory) external pure {
    return;
  }

  function setRewardManager(address rewardManager_) external { }
  
  function setRewardConfigurator(address rewardConfigurator_) external {
    _rewardConfigurator = rewardConfigurator_;
  }
}
