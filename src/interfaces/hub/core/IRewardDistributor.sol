// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRewardDistributor {
  function dispatch(uint256 eolId, address asset, uint256 amount, uint48 rewardedAt) external;

  function claim(uint256 eolId, address asset, uint48 rewardedAt) external;

  function claim(uint256 eolId, address asset, uint256 amountsClaimed, uint48 rewardedAt, bytes32[] calldata proof)
    external;
}
