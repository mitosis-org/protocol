// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { IEOLRewardRouter } from '../../src/interfaces/hub/eol/IEOLRewardRouter.sol';
import { IRewardDistributor } from '../../src/interfaces/hub/reward/IRewardDistributor.sol';

contract MockEOLRewardRouter is IEOLRewardRouter {
  function isRouterManager(address account) external view returns (bool) { }
  function getRewardTreasuryRewardInfos(address eolVault, address reward_, uint48 timestamp)
    external
    view
    returns (uint256[] memory amounts, bool[] memory dispatched)
  { }

  function setRouterManager(address account) external { }

  function routeExtraRewards(address, address reward, uint256 amount) external {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);
  }

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
