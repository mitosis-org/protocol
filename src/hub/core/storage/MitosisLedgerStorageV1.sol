// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract MitosisLedgerStorageV1 {
  using ERC7201Utils for string;

  struct ChainState {
    mapping(address asset => uint256 amount) amounts;
  }

  struct EOLState {
    EOLAmountState eolAmountState;
  }

  struct EOLAmountState {
    /// @dev total is the total amount of assets that have been finalized
    /// opt-in to Mitosis L1.
    /// Note: This value must match the totalSupply of the miAsset.
    uint256 total;
    /// @dev idle stores the amount of EOL temporarily returned for a
    /// specific purpose in the branch.
    /// Note: This value does not affect the calculation of the EOL
    /// allocation for a specific chain.
    uint256 idle;
    /// @dev optOutPending is a temporary value reflecting the opt-out
    /// request. This value is used to calculate the EOL allocation for
    /// each chain.
    /// (i.e. This means that from the point of the opt-out request, yield
    /// will not be provided for the corresponding miAsset)
    uint256 optOutPending;
    /// @dev optOutResolved is the actual amount used for the opt-out request
    /// resolvation.
    uint256 optOutResolved;
  }

  struct StorageV1 {
    mapping(uint256 chainId => ChainState state) chainStates;
    mapping(uint256 eolId => EOLState state) eolStates;
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
