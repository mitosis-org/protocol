// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor } from '../reward/IRewardDistributor.sol';

interface IEOLRewardManager {
  function routeYield(address eolVault, uint256 amount) external;

  function routeExtraRewards(address eolVault, address reward, uint256 amount) external;

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external;

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external;
}
