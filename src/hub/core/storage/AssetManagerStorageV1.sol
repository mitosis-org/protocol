// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { IAssetManagerEntrypoint } from '../../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IEOLVault } from '../../../interfaces/hub/eol/IEOLVault.sol';
import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { IEOLRewardManager } from '../../../interfaces/hub/eol/IEOLRewardManager.sol';

contract AssetManagerStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    IAssetManagerEntrypoint entrypoint;
    IMitosisLedger mitosisLedger;
    IEOLRewardManager rewardManager;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => address branchAsset)) branchAssets;
    mapping(uint256 chainId => mapping(address branchAsset => address hubAsset)) hubAssets;
  }

  string private constant _NAMESPACE = 'mitosis.storage.AssetManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
