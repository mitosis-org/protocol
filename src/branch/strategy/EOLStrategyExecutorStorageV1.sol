// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IEOLStrategyExecutor } from '../../interfaces/branch/strategy/IEOLStrategyExecutor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

abstract contract EOLStrategyExecutorStorageV1 {
  using ERC7201Utils for string;

  struct StrategyRegistry {
    // core fields
    uint256 len;
    mapping(uint256 => IEOLStrategyExecutor.Strategy) reg;
    mapping(address => uint256) idxByImpl;
    // peripheral fields
    uint256[] enabled;
  }

  struct StorageV1 {
    address strategist;
    address emergencyManager;
    StrategyRegistry strategies;
    uint256 lastSettledBalance;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLStrategyExecutorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
