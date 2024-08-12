// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../interfaces/hub/IMitosisLedger.sol';
import { MitosisLedgerStorageV1 } from './MitosisLedgerStorageV1.sol';

/// Note: This contract only stores state related to balances.
contract MitosisLedeger is IMitosisLedger, Ownable2StepUpgradeable, MitosisLedgerStorageV1 {
  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  // CHAIN

  function getAssetAmount(uint256 chain, address asset) external view returns (uint256) {
    return _getStorageV1().chainEntries[chain].deposits[asset];
  }

  // EOL

  function getEOLAllocateAmount(address miAsset) external view returns (uint256) {
    EOLState storage state = _getStorageV1().eolEntries[miAsset].state;
    return state.finalized - state.pending;
  }

  // Mutative functions

  function recordDeposit(uint256 chain, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainEntries[chain].deposits[asset] += amount;
  }

  function recordWithdraw(uint256 chain, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainEntries[chain].deposits[asset] -= amount;
  }

  function recordOptIn(address miAsset, uint256 amount) external /* auth */ {
    _getStorageV1().eolEntries[miAsset].state.finalized += amount;
  }

  // Note: Could be change parameters (add requestId parameter) in opt-out task.
  function recordOptOutRequest(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[miAsset].state;
    state.pending += amount;
  }

  function recordDeallocateEOL(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[miAsset].state;
    state.released += amount;
  }

  function recordOptOutResolve(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[miAsset].state;
    state.released -= amount;
    state.resolved += amount;

    // TODO(ray): Need to store below value in opt-out task.
    uint256 asset = IERC4626(miAsset).convertToAssets(amount);
  }

  function recordOptOutClaim(address miAsset, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[miAsset].state;
    state.pending -= amount;
    state.resolved -= amount;
    state.finalized -= amount;
  }
}
