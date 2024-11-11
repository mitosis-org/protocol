// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';

abstract contract RewardRedistributorStorageV1 {
  using ERC7201Utils for string;

  struct Redistribution {
    EnumerableMap.AddressToUintMap rewards;
    uint256 merkleStage;
    bytes32 merkleRoot;
  }

  struct StorageV1 {
    ITWABRewardDistributor twabRewardDistributor;
    IMerkleRewardDistributor merkleRewardDistributor;
    uint256 currentId;
    mapping(uint256 id => Redistribution) redistributions;
  }

  string private constant _NAMESPACE = 'mitosis.storage.RewardRedistributorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
