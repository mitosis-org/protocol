// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IGovMITO } from './IGovMITO.sol';

interface IGovMITOCommission {
  /**
   * @notice Error thrown when capacity is not enough
   */
  error NotEnoughCapacity();

  /**
   * @notice Returns the GovMITO token contract
   */
  function govMITO() external view returns (IGovMITO);

  /**
   * @notice Returns the capacity for a given spender
   * @param spender The address to check capacity for
   */
  function capacity(address spender) external view returns (uint256);

  /**
   * @notice Deposits ETH and mints gMITO tokens to this contract
   */
  function deposit() external payable;

  /**
   * @notice Forces withdrawal of gMITO tokens to owner
   * @param amount Amount of gMITO tokens to withdraw
   */
  function forceWithdraw(uint256 amount) external;

  /**
   * @notice Requests gMITO tokens based on caller's capacity
   * @param amount Amount of gMITO tokens to request
   */
  function request(uint256 amount) external;

  /**
   * @notice Increases capacity for a spender
   * @param spender Address to increase capacity for
   * @param amount Amount to increase capacity by
   */
  function increaseCapacity(address spender, uint256 amount) external;

  /**
   * @notice Decreases capacity for a spender
   * @param spender Address to decrease capacity for
   * @param amount Amount to decrease capacity by
   */
  function decreaseCapacity(address spender, uint256 amount) external;
}
