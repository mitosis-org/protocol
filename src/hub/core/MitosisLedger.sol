// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IEOLVault } from '../../interfaces/hub/core/IEOLVault.sol';
import { MitosisLedgerStorageV1 } from './storage/MitosisLedgerStorageV1.sol';

/// Note: This contract stores state related to balances, EOL states.
contract MitosisLedger is IMitosisLedger, Ownable2StepUpgradeable, MitosisLedgerStorageV1 {
  event EolIdSet(uint256 indexed eolId, address indexed eolVault);
  event EolStrategistSet(address indexed eolVault, address indexed strategist);
  event EolOptOutQueueSet(address indexed optOutQueue);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // View functions

  // CHAIN

  function lastEolId() external view returns (uint256) {
    return _getStorageV1().lastEolId;
  }

  function optOutQueue() external view returns (address) {
    return _getStorageV1().optOutQueue;
  }

  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256) {
    return _getStorageV1().chainStates[chainId].amounts[asset];
  }

  function eolStrategist(address eolVault_) external view returns (address) {
    return _getStorageV1().eolStates[eolVault_].strategist;
  }

  function eolAmountState(address eolVault_) external view returns (IMitosisLedger.EOLAmountState memory) {
    return _getStorageV1().eolStates[eolVault_].eolAmountState;
  }

  function getEOLAllocateAmount(address eolVault_) external view returns (uint256) {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    return state.total - state.optOutPending;
  }

  function eolVaultById(uint256 eolId) external view returns (address) {
    return _getStorageV1().eolVaultsById[eolId];
  }

  // Mutative functions

  // EOL management states

  function assignEolId(address eolVault_, address strategist) external returns (uint256 eolId /* auth */ ) {
    eolId = assignEolId(eolVault_);
    setEolStrategist(eolVault_, strategist);
  }

  function assignEolId(address eolVault_) public returns (uint256 eolId /* auth */ ) {
    StorageV1 storage $ = _getStorageV1();

    eolId = ++$.lastEolId;
    $.eolStates[eolVault_].eolVault = eolVault_;
    $.eolVaultsById[eolId] = eolVault_;

    emit EolIdSet(eolId, eolVault_);
  }

  function setEolStrategist(address eolVault_, address strategist) public /* auth */ {
    _getStorageV1().eolStates[eolVault_].strategist = strategist;
    emit EolStrategistSet(eolVault_, strategist);
  }

  function setOptOutQueue(address optOutQueue_) external /* auth */ {
    _getStorageV1().optOutQueue = optOutQueue_;
    emit EolOptOutQueueSet(optOutQueue_);
  }

  // Asset, EOL balance states

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] += amount;
  }

  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external /* auth */ {
    _getStorageV1().chainStates[chainId].amounts[asset] -= amount;
  }

  function recordOptIn(address eolVault_, uint256 amount) external /* auth */ {
    _getStorageV1().eolStates[eolVault_].eolAmountState.total += amount;
  }

  function recordOptOutRequest(address eolVault_, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    state.optOutPending += amount;
  }

  function recordAllocateEOL(address eolVault_, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    state.idle -= amount;
  }

  function recordDeallocateEOL(address eolVault_, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    state.idle += amount;
  }

  function recordOptOutResolve(address eolVault_, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    state.idle -= amount;
    state.optOutResolved += amount;
  }

  function recordOptOutClaim(address eolVault_, uint256 amount) external /* auth */ {
    EOLAmountState storage state = _getStorageV1().eolStates[eolVault_].eolAmountState;
    state.optOutPending -= amount;
    state.optOutResolved -= amount;
    state.total -= amount;
  }
}
