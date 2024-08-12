// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AssetAction, EOLAction } from '@src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '@src/interfaces/branch/IMitosisVaultEntrypoint.sol';

abstract contract MitosisVaultStorageV1 {
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

  /// @custom:storage-location erc7201:mitosis.storage.BasicVault.v1
  struct StorageV1 {
    IMitosisVaultEntrypoint entrypoint;
    mapping(address asset => AssetInfo) assets;
    mapping(uint256 eolId => EOLInfo) eols;
  }

  // keccak256(abi.encode(uint256(keccak256("mitosis.storage.BasicVault.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0xdfd1d7385a5871446aad353015e13a89d148fc3945543ae58683c6905a730600;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}
