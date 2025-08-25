// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { StdError } from '../../lib/StdError.sol';
import { VLFStrategyExecutor } from './VLFStrategyExecutor.sol';

contract VLFStrategyExecutorMigration is VLFStrategyExecutor {
  function manualSettle() external virtual returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == address($.vault), StdError.Unauthorized());

    uint256 storedTotalBalance = $.storedTotalBalance;

    uint256 totalBalance = _totalBalance($);
    require(totalBalance >= storedTotalBalance, 'totalBalance < storedTotalBalance');

    $.storedTotalBalance = totalBalance;
    uint256 diff = totalBalance - storedTotalBalance;

    return diff;
  }
}
