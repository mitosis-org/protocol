// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { MitosisLedgerStorageV1 } from './storage/MitosisLedgerStorageV1.sol';

/// Note: This contract stores state related to balances, EOL states.
contract MitosisLedger is IMitosisLedger, Ownable2StepUpgradeable, MitosisLedgerStorageV1 {
  event EolStrategistSet(address eolVault, address strategist);

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

  function eolStrategist(address eolVault) external view returns (address) {
    return _getStorageV1().eolStates[eolVault].strategist;
  }

  function eolAmountState(address eolVault) external view returns (IMitosisLedger.EOLAmountState memory) {
    return _getStorageV1().eolStates[eolVault].eolAmountState;
  }

  function getEOLAllocateAmount(address eolVault) external view returns (uint256) {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    return state.total - state.optOutPending;
  }

  // Mutative functions

  // EOL management states

  function setEolStrategist(address eolVault, address strategist) public /* auth */ {
    _getStorageV1().eolStates[eolVault].strategist = strategist;
    emit EolStrategistSet(eolVault, strategist);
  }

  // Asset, EOL balance states

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] += amount;
  }

  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] -= amount;
  }

  function recordOptIn(address eolVault, uint256 amount) external /* auth */ {
    _getStorageV1().eolStates[eolVault].eolAmountState.total += amount;
  }

  function recordOptOutRequest(address eolVault, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    state.optOutPending += amount;
  }

  function recordAllocateEOL(address eolVault, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    state.idle -= amount;
  }

  function recordDeallocateEOL(address eolVault, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    state.idle += amount;
  }

  function recordOptOutResolve(address eolVault, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    state.idle -= amount;
    state.optOutResolved += amount;
  }

  function recordOptOutClaim(address eolVault, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault].eolAmountState;
    state.optOutPending -= amount;
    state.optOutResolved -= amount;
    state.total -= amount;
  }
}
