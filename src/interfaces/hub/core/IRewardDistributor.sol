// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRewardDistributor {
  function dispatch(uint256 eolId, address asset, uint256 amount, uint48 rewardedAt) external;
}
