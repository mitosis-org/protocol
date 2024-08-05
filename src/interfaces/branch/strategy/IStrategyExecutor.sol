// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { IMitosisVault } from '@src/interfaces/branch/IMitosisVault.sol';

interface IStrategyExecutor {
  struct Strategy {
    uint256 priority;
    address implementation;
    bool enabled;
  }
  // TODO: add more fields

  // immutable
  function vault() external view returns (IMitosisVault vault_);
  function asset() external view returns (IERC20 asset_);

  // storage v1
  function strategist() external view returns (address strategist_);

  function getStrategy(uint256 strategyId) external view returns (Strategy memory strategy);
  function getStrategy(address implementation) external view returns (Strategy memory strategy);
  function getEnabledStrategyIds() external view returns (uint256[] memory strategyIds);
  function isStrategyEnabled(uint256 strategyId) external view returns (bool enabled);
  function isStrategyEnabled(address implementation) external view returns (bool enabled);

  // executions (strategy)
  struct Call {
    uint256 strategyId;
    bytes[] callData;
  }

  function execute(Call[] calldata calls, uint256 useEOL) external;
}
