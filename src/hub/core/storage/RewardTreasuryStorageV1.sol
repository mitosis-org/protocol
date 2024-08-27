// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract RewardTreasuryStorageV1 {
  using ERC7201Utils for string;

  struct RewardInfo {
    address asset;
    uint256 amount;
    bool dispatched;
  }

  struct StorageV1 {
    IMitosisLedger mitosisLedger;
    mapping(uint256 eolId => mapping(uint48 timestamp => RewardInfo[])) rewards;
  }

  string private constant _NAMESPACE = 'mitosis.storage.RewardTreasuryStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
