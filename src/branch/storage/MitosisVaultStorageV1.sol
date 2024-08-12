// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AssetAction, EOLAction } from '@src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '@src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { ERC7201Utils } from '@src/lib/ERC7201Utils.sol';

abstract contract MitosisVaultStorageV1 {
  using ERC7201Utils for string;

  struct AssetInfo {
    bool initialized;
    mapping(AssetAction => bool) isHalted;
  }

  struct EOLInfo {
    bool initialized;
    address asset;
    address strategyExecutor;
    uint256 availableEOL;
    mapping(EOLAction => bool) isHalted;
  }

  struct StorageV1 {
    IMitosisVaultEntrypoint entrypoint;
    mapping(address asset => AssetInfo) assets;
    mapping(uint256 eolId => EOLInfo) eols;
  }

  string constant _NAMESPACE = 'mitosis.storage.MitosisVaultStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
