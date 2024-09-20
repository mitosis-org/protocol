// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from '../../src/interfaces/hub/reward/IRewardConfigurator.sol';

contract MockRewardConfigurator is IRewardConfigurator {
  uint256 _precision;

  constructor(uint256 precision) {
    _precision = precision;
  }

  function rewardRatioPrecision() external view returns (uint256) {
    return _precision;
  }
}
