// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

import { IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { IStrategyExecutor } from '@src/interfaces/branch/strategy/IStrategyExecutor.sol';

abstract contract StrategyExecutorStorageV1 {
  struct StrategyRegistry {
    // core fields
    uint256 len;
    mapping(uint256 => IStrategyExecutor.Strategy) reg;
    mapping(address => uint256) idxByImpl;
    // peripheral fields
    uint256[] enabled;
  }

  /// @custom:storage-location erc7201:mitosis.storage.StrategyExecutor.v1
  struct StorageV1 {
    address strategist;
    address emergencyManager;
    StrategyRegistry strategies;
    uint256 lastSettledBalance;
  }

  // keccak256(abi.encode(uint256(keccak256("mitosis.storage.StrategyExecutor.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0xc82bbd26dd04b8fda5b91a017b56a35bba7a0ae717f406fd17b11f4bdfb4ab00;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}
