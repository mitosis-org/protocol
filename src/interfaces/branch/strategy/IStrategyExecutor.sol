// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';

import { IMitosisVault } from '../IMitosisVault.sol';

interface IStrategyExecutor {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event TallySet(address indexed implementation);
  event StrategistSet(address indexed strategist);
  event ExecutorSet(address indexed executor);

  function execute(address target, bytes calldata data, uint256 value) external returns (bytes memory result);

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
    external
    returns (bytes[] memory results);
}
