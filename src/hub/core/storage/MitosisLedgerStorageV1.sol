// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract MitosisLedgerStorageV1 {
  using ERC7201Utils for string;

  struct ChainState {
    mapping(address asset => uint256 amount) amounts;
  }

  struct EOLState {
    address strategist;
    IMitosisLedger.EOLAmountState eolAmountState;
  }

  struct StorageV1 {
    address optOutQueue;
    mapping(uint256 chainId => ChainState state) chainStates;
    mapping(address eolVault => EOLState state) eolStates;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisLedgerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
