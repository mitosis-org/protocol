// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import { IStrategyExecutor } from '../../src/interfaces/branch/strategy/IStrategyExecutor.sol';

contract MockStrategyExecutor is IStrategyExecutor {
  uint256 public lastExecuteValue;
  uint256[] public lastExecuteValues;

  function execute(address target, bytes calldata data, uint256 value) external payable returns (bytes memory result) {
    lastExecuteValue = value;
  }

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
    external
    payable
    returns (bytes[] memory result)
  {
    lastExecuteValues = values;
    if (values.length > 0) lastExecuteValue = values[0];
  }
}
