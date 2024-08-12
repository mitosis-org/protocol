// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IMitosisLedger } from '../interfaces/hub/IMitosisLedger.sol';

/// Note: This contract only stores state related to balances.
contract MitosisLedeger is IMitosisLedger {
  struct ChainEntry {
    mapping(address asset => uint256 amount) deposits;
  }

  struct EolEntry {
    EolState state;

    // TODO(ray): asset - miAsset raio snapshot
  }

  struct EolState {
    uint256 pending;
    uint256 released;
    uint256 resolved;
    uint256 finalized;
  }

  mapping(uint256 chain => ChainEntry) _chainEntries;
  mapping(address miAsset => EolEntry) _eolEntries;

  // View functions

  // CHAIN

  function getAssetAmount(uint256 chain, address asset) external view returns (uint256) {
    return _chainEntries[chain].deposits[asset];
  }

  // EOL

  function getEolAllocateAmount(address miAsset) external view returns (uint256) {
    EolState storage state = _eolEntries[miAsset].state;
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

  function recordOptOutRequest(address miAsset, uint256 amount) external /* auth */ {
    EolState storage state = _eolEntries[miAsset].state;
    state.pending += amount;
  }

  function recordOptOutRelease(address miAsset, uint256 amount) external /* auth */ {
    EolState storage state = _eolEntries[miAsset].state;
    state.released += amount;
  }

  function recordOptOutResolve(address miAsset, uint256 amount) external /* auth */ {
    EolState storage state = _eolEntries[miAsset].state;
    state.released -= amount;
    state.resolved += amount;
    // TODO(ray): take a snapshot about `asset - miAsset` ratio
  }

  function recordOptOutClaim(address miAsset, uint256 amount) external /* auth */ {
    EolState storage state = _eolEntries[miAsset].state;
    state.pending -= amount;
    state.resolved -= amount;
    state.finalized -= amount;
  }
}
