// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IDelegationRegistry } from '../../interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../../lib/StdError.sol';
import { DelegationRegistryStorageV1 } from './DelegationRegistryStorageV1.sol';

contract DelegationRegistry is IDelegationRegistry, DelegationRegistryStorageV1, ContextUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer { }

  function delegationManager(address account) external view override returns (address delegationManager_) {
    return _getStorageV1().delegationManagers[account];
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _getStorageV1().defaultDelegatees[account];
  }

  function setDelegationManager(address delegationManager_) external override {
    _getStorageV1().delegationManagers[_msgSender()] = delegationManager_;
    emit DelegationManagerSet(_msgSender(), delegationManager_);
  }

  function setDefaultDelegatee(address defaultDelegatee_) external override {
    _getStorageV1().defaultDelegatees[_msgSender()] = defaultDelegatee_;
    emit DefaultDelegateeSet(_msgSender(), defaultDelegatee_);
  }

  function setDefaultDelegateByManager(address account, address defaultDelegatee_) external override {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == $.delegationManagers[account], StdError.Unauthorized());

    $.defaultDelegatees[account] = defaultDelegatee_;
    emit DefaultDelegateeSet(account, defaultDelegatee_);
  }
}
