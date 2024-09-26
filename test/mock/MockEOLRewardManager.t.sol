// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { IEOLRewardManager } from '../../src/interfaces/hub/eol/IEOLRewardManager.sol';
import { IRewardDistributor } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockEOLRewardManager is IEOLRewardManager {
  function routeYield(address eolVault, uint256 amount) external {
    address asset = IERC4626(eolVault).asset();
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
  }

  function routeExtraRewards(address eolVault, address reward, uint256 amount) external { }

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external { }

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external { }
}
