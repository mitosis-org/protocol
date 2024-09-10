// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRewardConfigurator {
  function rewardRatioPrecision() external view returns (uint256);
}
