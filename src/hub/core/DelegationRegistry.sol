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
    return _delegationManager(_getStorageV1(), account);
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _getStorageV1().defaultDelegatees[account];
  }

  function setDelegationManager(address account, address delegationManager_) external override {
    StorageV1 storage $ = _getStorageV1();
    _assertSelfOrManager($, account);

    $.delegationManagers[account] = delegationManager_;
    emit DelegationManagerSet(account, _msgSender(), delegationManager_);
  }

  function setDefaultDelegatee(address account, address defaultDelegatee_) external override {
    StorageV1 storage $ = _getStorageV1();
    _assertSelfOrManager($, account);

    $.defaultDelegatees[account] = defaultDelegatee_;
    emit DefaultDelegateeSet(account, _msgSender(), defaultDelegatee_);
  }

  function _delegationManager(StorageV1 storage $, address account) internal view returns (address delegationManager_) {
    delegationManager_ = $.delegationManagers[account];
    return delegationManager_ == address(0) ? account : delegationManager_; // default to account
  }

  function _assertSelfOrManager(StorageV1 storage $, address account) private view {
    address sender = _msgSender();
    require(sender == account || sender == _delegationManager($, account), StdError.Unauthorized());
  }
}
