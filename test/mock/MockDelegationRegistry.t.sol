// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDelegationRegistry } from '../../src/interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract MockDelegationRegistry is IDelegationRegistry {
  address private immutable _mitosis;
  mapping(address account => address delegationManager) private _delegationManagers;
  mapping(address account => address defaultDelegatee) private _defaultDelegatees;
  mapping(address account => address redistributionRule) private _redistributionRules;

  constructor(address mitosis_) {
    _mitosis = mitosis_;
  }

  function mitosis() external view returns (address mitosis_) {
    return _mitosis;
  }

  function delegationManager(address account) external view returns (address delegationManager_) {
    return _delegationManagers[account];
  }

  function defaultDelegatee(address account) external view returns (address defaultDelegatee_) {
    return _defaultDelegatees[account];
  }

  function setDelegationManager(address account, address delegationManager_) external {
    require(msg.sender == account || msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _delegationManagers[account] = delegationManager_;
  }

  function setDefaultDelegatee(address account, address defaultDelegatee_) external {
    require(msg.sender == account || msg.sender == _delegationManagers[account], StdError.Unauthorized());
    _defaultDelegatees[account] = defaultDelegatee_;
  }

  function setDelegationManagerByMitosis(address requester, address account, address delegationManager_) external {
    require(requester == _mitosis, StdError.Unauthorized());
    require(requester == account || requester == _delegationManagers[account], StdError.Unauthorized());
    _delegationManagers[account] = delegationManager_;
  }

  function setDefaultDelegateeByMitosis(address requester, address account, address defaultDelegatee_) external {
    require(requester == _mitosis, StdError.Unauthorized());
    require(requester == account || requester == _delegationManagers[account], StdError.Unauthorized());
    _defaultDelegatees[account] = defaultDelegatee_;
  }
}
