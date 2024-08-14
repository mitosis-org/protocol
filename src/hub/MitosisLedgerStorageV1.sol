// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

contract MitosisLedgerStorageV1 {
  using ERC7201Utils for string;

  struct ChainEntry {
    mapping(address asset => uint256 amount) deposits;
  }

  struct EOLEntry {
    EOLState state;
  }

  // TODO(ray): asset - miAsset raio snapshot

  struct EOLState {
    /// @dev pending is a temporary value reflecting the opt-out request
    /// This value is used to calculate the EOL allocation for each chain.
    /// (i.e. This means that from the point of the opt-out request, yield
    /// will not be provided for the corresponding miAsset)
    uint256 pending;
    /// @dev reserved is a state that temporarily stores the reduced EOL
    /// value assigned to the MitosisVault.
    /// Note: It is a state for allows the logic for settling in Mitosis L1
    /// and the logic for resolving the opt-out request to be executed
    /// separately.
    uint256 reserved;
    /// @dev resvoled is the actual amount used for the opt-out request
    /// resolvation.
    //
    // FIXME(ray)
    uint256 resolved;
    /// @dev finalized is the total amount of assets that have been finalized
    /// opt-in to Mitosis L1.
    /// Note: This value must match the totalSupply of the miAsset.
    uint256 finalized;
  }

  struct StorageV1 {
    mapping(uint256 chainId => ChainEntry entry) chainEntries;
    mapping(uint256 eolId => EOLEntry entry) eolEntries;
  }

  string constant _NAMESPACE = 'mitosis.storage.MitosisLedgerStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
