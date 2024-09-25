// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IGlobalAccessControlManager } from '../interfaces/auth/IGlobalAccessControlManager.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

abstract contract MitosisVaultStorageV1 {
  using ERC7201Utils for string;

  struct AssetInfo {
    bool initialized;
  }

  struct EOLInfo {
    bool initialized;
    address asset;
    address strategyExecutor;
    uint256 availableEOL;
  }

  struct StorageV1 {
    IGlobalAccessControlManager globalAccessControlManager;
    IMitosisVaultEntrypoint entrypoint;
    mapping(address asset => AssetInfo) assets;
    mapping(address hubEOLVault => EOLInfo) eols;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisVaultStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
