// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { MitosisLedgerStorageV1 } from './storage/MitosisLedgerStorageV1.sol';

/// Note: This contract stores state related to balances, EOL states.
contract MitosisLedger is IMitosisLedger, Ownable2StepUpgradeable, MitosisLedgerStorageV1 {
  event EolIdSet(uint256 eolId, address eolVault);
  event EolStrategistSet(uint256 eolId, address strategist);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  // CHAIN

  function currentEolId() external view returns (uint256) {
    uint256 nextEolId = _getStorageV1().nextEolId;
    if (nextEolId == 0) revert('not yet');
    return nextEolId - 1;
  }

  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256) {
    return _getStorageV1().chainStates[chainId].amounts[asset];
  }

  function eolVault(uint256 eolId) external view returns (address) {
    return _getStorageV1().eolStates[eolId].eolVault;
  }

  function eolStrategist(uint256 eolId) external view returns (address) {
    return _getStorageV1().eolStates[eolId].strategist;
  }

  function eolAmountState(uint256 eolId)
    external
    view
    returns (uint256 total, uint256 idle, uint256 optOutPending, uint256 optOutResolved)
  {
    EOLAmountState memory state = _getStorageV1().eolStates[eolId].eolAmountState;
    return (state.total, state.idle, state.optOutPending, state.optOutResolved);
  }

  function getEOLAllocateAmount(uint256 eolId) external view returns (uint256) {
    EOLAmountState storage state = _getStorageV1().eolStates[eolId].eolAmountState;
    return state.total - state.optOutPending;
  }

  // Mutative functions

  function assignEolId(address eolVault_, address strategist) external returns (uint256 eolId /* auth */ ) {
    StorageV1 storage $ = _getStorageV1();

    eolId = $.nextEolId;
    $.eolStates[eolId].eolVault = eolVault_;
    $.eolStates[eolId].strategist = strategist;
    $.eolIds[eolVault_] = eolId;
    $.nextEolId++;

    emit EolIdSet(eolId, eolVault_);
  }

  function setEolStrategist(uint256 eolId, address strategist) external /* auth */ {
    _getStorageV1().eolStates[eolId].strategist = strategist;
    emit EolStrategistSet(eolId, strategist);
  }

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
