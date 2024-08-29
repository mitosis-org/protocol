// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEOLRewardManager {
  function routeReward(address eolVault, address reward, uint256 amount) external;
}
