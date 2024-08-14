// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../interfaces/hub/IMitosisLedger.sol';
import { MitosisLedgerStorageV1 } from './MitosisLedgerStorageV1.sol';
import { StdError } from '../lib/StdError.sol';

/// Note: This contract only stores state related to balances.
contract MitosisLedger is IMitosisLedger, Ownable2StepUpgradeable, MitosisLedgerStorageV1 {
  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  // CHAIN

  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256) {
    return _getStorageV1().chainEntries[chainId].depositAmounts[asset];
  }

  // EOL

  function eolState(uint256 eolId) external view returns (EOLState memory) {
    return _getStorageV1().eolEntries[eolId].state;
  }

  function getEOLAllocateAmount(uint256 eolId) external view returns (uint256) {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    return state.finalized - state.pending;
  }

  // Mutative functions

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainEntries[chainId].depositAmounts[asset] += amount;
  }

  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    ChainEntry storage chain = _getStorageV1().chainEntries[chainId];
    if (chain.depositAmounts[asset] < amount) {
      revert StdError.ArithmeticError();
    }
    chain.depositAmounts[asset] -= amount;
  }

  function recordOptIn(uint256 eolId, uint256 amount) external /* auth */ {
    _getStorageV1().eolEntries[eolId].state.finalized += amount;
  }

  function recordOptOutRequest(uint256 eolId, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    state.pending += amount;
    // TODO(ray): Need to store below value in opt-out task.
    // uint256 asset = IERC4626(eolId).convertToAssets(amount);
  }

  function recordAllocateEOL(uint256 eolId, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    state.reserved -= amount;
  }

  function recordReserveEOL(uint256 eolId, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    state.reserved += amount;
  }

  function recordOptOutResolve(uint256 eolId, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    state.reserved -= amount;
    state.resolved += amount;
    // TODO(ray): Need to store below value in opt-out task.
    // uint256 asset = IERC4626(eolId).convertToAssets(amount);
  }

  function recordOptOutClaim(uint256 eolId, uint256 amount) external /* auth */ {
    EOLState storage state = _getStorageV1().eolEntries[eolId].state;
    state.pending -= amount;
    state.resolved -= amount;
    state.finalized -= amount;
  }
}
