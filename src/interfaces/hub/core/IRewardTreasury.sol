// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IRewardDistributor } from './IRewardDistributor.sol';

interface IRewardTreasury {
  function deposit(uint256 eolId, address asset, uint256 amount, uint48 timestamp) external;

  function dispatchTo(IRewardDistributor distributor, uint256 eolId, address asset, uint48 timestamp) external;
}
