// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/interfaces/IERC20.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { VLFStrategyExecutorMigration } from '../../src/branch/strategy/VLFStrategyExecutorMigration.sol';
import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract MockVLFStrategyExecutorMigration is VLFStrategyExecutorMigration {
  uint256 private _mockSettleReturn;
  bool private _shouldRevert;

  function setMockSettleReturn(uint256 amount) external {
    _mockSettleReturn = amount;
  }

  function setShouldRevert(bool shouldRevert) external {
    _shouldRevert = shouldRevert;
  }

  function manualSettle() external override returns (uint256) {
    if (_shouldRevert) {
      revert('Mock revert');
    }

    // Check if caller is vault (same authorization check as original)
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == address($.vault), StdError.Unauthorized());

    return _mockSettleReturn;
  }
}
