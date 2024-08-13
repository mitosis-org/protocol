// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

import { IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { IStrategyExecutor } from '../../../interfaces/branch/strategy/IStrategyExecutor.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

abstract contract StrategyExecutorStorageV1 {
  using ERC7201Utils for string;

  struct StrategyRegistry {
    // core fields
    uint256 len;
    mapping(uint256 => IStrategyExecutor.Strategy) reg;
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

  string constant _NAMESPACE = 'mitosis.storage.StrategyExecutorStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
