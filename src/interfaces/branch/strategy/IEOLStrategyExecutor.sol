// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';

import { IMitosisVault } from '../IMitosisVault.sol';

interface IEOLStrategyExecutor {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event StrategyAdded(uint256 indexed strategyId, address indexed implementation, uint256 priority);
  event StrategyEnabled(uint256 indexed strategyId);
  event StrategyDisabled(uint256 indexed strategyId);

  event EmergencyManagerSet(address indexed emergencyManager);
  event StrategistSet(address indexed strategist);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IEOLStrategyExecutor__StrategistNotSet();
  error IEOLStrategyExecutor__StrategyAlreadySet(address implementation, uint256 strategyId);
  error IEOLStrategyExecutor__StrategyAlreadyEnabled(uint256 strategyId);
  error IEOLStrategyExecutor__StrategyNotEnabled(uint256 strategyId);

  struct Strategy {
    uint256 priority;
    address implementation;
    bool enabled;
    // TODO(thai): `context` is necessary to track `totalBalance`.
    //   But, it seems not good design to keep it in this struct.
    //   It'd be better to make `struct Position` and move this field to there.
    bytes context;
  }

  // TODO: add more fields

  // immutable
  function vault() external view returns (IMitosisVault vault_);
  function asset() external view returns (IERC20 asset_);
  function hubEOLVault() external view returns (address hubEOLVault_);

  // storage v1
  function strategist() external view returns (address strategist_);

  function strategyId(address implementation) external view returns (uint256);
  function getStrategy(uint256 strategyId_) external view returns (Strategy memory);
  function getStrategy(address implementation) external view returns (Strategy memory);
  function getEnabledStrategyIds() external view returns (uint256[] memory);
  function isStrategyEnabled(uint256 strategyId_) external view returns (bool);
  function isStrategyEnabled(address implementation) external view returns (bool);

  function totalBalance() external view returns (uint256);
  function storedTotalBalance() external view returns (uint256);

  function fetchEOL(uint256 amount) external;
  function returnEOL(uint256 amount) external;
  function settle() external;
  function settleExtraRewards(address reward, uint256 amount) external;

  // executions (strategy)
  struct Call {
    uint256 strategyId;
    bytes[] callData;
  }

  function execute(Call[] calldata calls) external;
}
