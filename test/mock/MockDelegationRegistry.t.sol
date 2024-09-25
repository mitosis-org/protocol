// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDelegationRegistry } from '../../src/interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract MockDelegationRegistry is IDelegationRegistry {
  mapping(address account => address delegationManager) private _delegationManagers;
  mapping(address account => address defaultDelegatee) private _defaultDelegatees;

  function delegationManager(address account) external view override returns (address delegationManager_) {
    return _delegationManagers[account];
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _defaultDelegatees[account];
  }

  function setDelegationManager(address delegationManager_) external override {
    _delegationManagers[msg.sender] = delegationManager_;
  }

  function setDefaultDelegatee(address defaultDelegatee_) external override {
    _defaultDelegatees[msg.sender] = defaultDelegatee_;
  }

  function setDefaultDelegateByManager(address account, address defaultDelegatee_) external override {
    require(msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _defaultDelegatees[account] = defaultDelegatee_;
  }
}
