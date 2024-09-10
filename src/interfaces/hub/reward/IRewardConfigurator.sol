// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRewardConfigurator {
  /// @dev Returns the reward precision.
  function rewardRatioPrecision() external view returns (uint256);
}
