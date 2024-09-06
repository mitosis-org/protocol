// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DistributionType } from '../../src/interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../src/interfaces/hub/eol/IEOLRewardDistributor.sol';

contract MockDistributor is IEOLRewardDistributor {
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

  function claimable(address, address, address, bytes memory) external pure returns (bool) {
    return true;
  }

  function handleReward(address, address, uint256, bytes memory) external pure {
    return;
  }
}
