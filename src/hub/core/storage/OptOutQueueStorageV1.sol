// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../../lib/LibRedeemQueue.sol';

contract OptOutQueueStorageV1 {
  using ERC7201Utils for string;

  struct EOLVaultState {
    // queue
    bool isEnabled;
    uint256 breadcrumb;
    LibRedeemQueue.Queue queue;
    // vault
    uint8 decimalsOffset;
    uint8 underlyingDecimals;
    mapping(uint256 requestId => uint256 assets) sharesByRequestId;
  }

  struct StorageV1 {
    IMitosisLedger ledger;
    mapping(address eolVault => EOLVaultState state) states;
  }

  string private constant _NAMESPACE = 'mitosis.storage.OptOutQueueStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
