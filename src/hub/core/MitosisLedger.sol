// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { MitosisLedgerStorageV1 } from './storage/MitosisLedgerStorageV1.sol';

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
    return _getStorageV1().chainStates[chainId].amounts[asset];
  }

  // EOL

  function eolAmountState(uint256 eolId) external view returns (EOLAmountState memory) {
    return _getStorageV1().eolStates[eolId].eolAmountState;
  }

  function getEOLAllocateAmount(uint256 eolId) external view returns (uint256) {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    return state.total - state.optOutPending;
  }

  // Mutative functions

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] += amount;
  }

  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] -= amount;
  }

  function recordOptIn(uint256 eolId, uint256 amount) external /* auth */ {
    _getStorageV1().eolStates[eolId].eolAmountState.total += amount;
  }

  function recordOptOutRequest(uint256 eolId, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    state.optOutPending += amount;
  }

  function recordAllocateEOL(uint256 eolId, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    state.idle -= amount;
  }

  function recordDeallocateEOL(uint256 eolId, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    state.idle += amount;
  }

  function recordOptOutResolve(uint256 eolId, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    state.idle -= amount;
    state.optOutResolved += amount;
  }

  function recordOptOutClaim(uint256 eolId, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    state.optOutPending -= amount;
    state.optOutResolved -= amount;
    state.total -= amount;
  }
}
