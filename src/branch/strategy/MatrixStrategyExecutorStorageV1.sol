// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { ITally } from '../../interfaces/branch/strategy/tally/ITally.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

abstract contract MatrixStrategyExecutorStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    address strategist;
    address executor;
    address emergencyManager;
    uint256 storedTotalBalance;
    ITally tally;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MatrixStrategyExecutorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
