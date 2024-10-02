// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDelegationRegistry } from '../../src/interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract MockDelegationRegistry is IDelegationRegistry {
  mapping(address account => address delegationManager) private _delegationManagers;
  mapping(address account => address defaultDelegatee) private _defaultDelegatees;
  mapping(address account => address redistributionRule) private _redistributionRules;

  function delegationManager(address account) external view override returns (address delegationManager_) {
    return _delegationManagers[account];
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _defaultDelegatees[account];
  }

  function redistributionRule(address account) external view override returns (address redistributionRule_) {
    return _redistributionRules[account];
  }

  function setDelegationManager(address account, address delegationManager_) external override {
    require(msg.sender == account || msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _delegationManagers[account] = delegationManager_;
  }

  function setDefaultDelegatee(address account, address defaultDelegatee_) external override {
    require(msg.sender == account || msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _defaultDelegatees[account] = defaultDelegatee_;
  }

  function setRedistributionRule(address account, address redistributionRule_) external override {
    require(redistributionRule_.code.length > 0, StdError.InvalidAddress('redistributionRule'));
    require(msg.sender == account || msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _redistributionRules[account] = redistributionRule_;
  }
}
