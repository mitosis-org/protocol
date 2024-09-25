// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IVoteManager } from '../../interfaces/hub/core/IVoteManager.sol';
import { VoteManagerStorageV1 } from './VoteManagerStorageV1.sol';

contract VoteManager is IVoteManager, VoteManagerStorageV1, ContextUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer { }

  function delegationManager(address account) external view override returns (address delegationManager_) {
    return _getVoteManagerStorageV1().delegationManagers[account];
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _getVoteManagerStorageV1().defaultDelegatees[account];
  }

  function setDelegationManager(address delegationManager_) external override {
    _getVoteManagerStorageV1().delegationManagers[_msgSender()] = delegationManager_;
    emit DelegationManagerSet(_msgSender(), delegationManager_);
  }

  function setDefaultDelegatee(address defaultDelegatee_) external override {
    _getVoteManagerStorageV1().defaultDelegatees[_msgSender()] = defaultDelegatee_;
    emit DefaultDelegateeSet(_msgSender(), defaultDelegatee_);
  }
}
