// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRewardConfigurator
 * @author Manythings Pte. Ltd.
 * @dev Interface for configuring reward distribution parameters.
 */
interface IRewardConfigurator {
  /**
   * @notice Returns the precision used for reward ratios.
   * @return The precision value for reward ratios.
   */
  function rewardRatioPrecision() external view returns (uint256);
}
