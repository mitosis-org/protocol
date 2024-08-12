// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { IMitosisLedger } from '../interfaces/hub/IMitosisLedger.sol';

/// Note: This contract only stores state related to balances.
contract MitosisLedeger is IMitosisLedger {
  struct ChainEntry {
    mapping(address asset => uint256 amount) deposits;
  }

  struct EOLEntry {
    EOLState state;

    // TODO(ray): asset - miAsset raio snapshot
  }

  struct EOLState {
    /// @dev pending is a temporary value reflecting the opt-out request
    /// This value is used to calculate the EOL allocation for each chain.
    /// (i.e. This means that from the point of the opt-out request, yield
    /// will not be provided for the corresponding miAsset)
    uint256 pending;

    /// @dev released is the state temporarily storing the value released
    /// from the MitosisVault of the branch when it is uploaded (MsgDeallocateEOL).
    /// This value is used when resolving the opt-out request.
    /// Note: It is a state that allows the logic for settling in Mitosis L1
    /// and the logic for resolving the opt-out request to be executed
    /// separately.
    uint256 released;

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

  mapping(uint256 chain => ChainEntry) _chainEntries;
  mapping(address miAsset => EOLEntry) _eolEntries;

  // View functions

  // CHAIN

  function getAssetAmount(uint256 chain, address asset) external view returns (uint256) {
    return _chainEntries[chain].deposits[asset];
  }

  // EOL

  function getEOLAllocateAmount(address miAsset) external view returns (uint256) {
    EOLState storage state = _eolEntries[miAsset].state;
    return state.finalized - state.pending;
  }

  // Mutative functions

  function recordDeposit(uint256 chain, address asset, uint256 amount) external /* auth */ {
    _chainEntries[chain].deposits[asset] += amount;
  }

  function recordWithdraw(uint256 chain, address asset, uint256 amount) external /* auth */ {
    _chainEntries[chain].deposits[asset] -= amount;
  }

  function recordOptIn(address miAsset, uint256 amount) external /* auth */ {
    _eolEntries[miAsset].state.finalized += amount;
  }

  // Note: Could be change parameters (add requestId parameter) in opt-out task.
  function recordOptOutRequest(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _eolEntries[miAsset].state;
    state.pending += amount;
  }

  function recordDeallocateEOL(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _eolEntries[miAsset].state;
    state.released += amount;
  }

  function recordOptOutResolve(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _eolEntries[miAsset].state;
    state.released -= amount;
    state.resolved += amount;

    // TODO(ray): Need to store below value in opt-out task.
    uint256 asset = IERC4626(miAsset).convertToAssets(amount);
  }

  function recordOptOutClaim(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _eolEntries[miAsset].state;
    state.pending -= amount;
    state.resolved -= amount;
    state.finalized -= amount;
  }
}
