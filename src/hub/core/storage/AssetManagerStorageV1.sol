// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AssetManagerEntrypoint } from '../AssetManagerEntrypoint.sol';
import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { IRewardTreasury } from '../../../interfaces/hub/core/IRewardTreasury.sol';
import { IEOLVault } from '../../../interfaces/hub/core/IEOLVault.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract AssetManagerStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    AssetManagerEntrypoint entrypoint;
    IMitosisLedger mitosisLedger;
    IRewardTreasury rewardTreasury;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => address branchAsset)) branchAssets;
    mapping(address branchAsset => address hubAsset) hubAssets;
    // EOL states
    mapping(uint256 eolId => address strategist) strategists;
    mapping(uint256 eolId => IEOLVault eolVault) eolVaults;
  }

  string constant _NAMESPACE = 'mitosis.storage.AssetManagerStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
