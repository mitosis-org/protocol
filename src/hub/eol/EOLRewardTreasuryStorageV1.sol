// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

contract EOLRewardTreasuryStorageV1 {
  using ERC7201Utils for string;

  struct RewardInfo {
    address asset;
    uint256 amount;
    bool dispatched;
  }

  struct StorageV1 {
    address assetManager;
    IEOLRewardConfigurator rewardConfigurator;
    mapping(address account => bool granted) isTreasuryManager;
    mapping(address eolVault => mapping(uint48 timestamp => RewardInfo[] rewardInfos)) rewards;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLRewardTreasuryStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
