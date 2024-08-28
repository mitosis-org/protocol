// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRewardTreasury {
  function deposit(address asset, uint256 amount, uint48 timestamp) external;
}
