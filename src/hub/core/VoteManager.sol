// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IVoteManager } from '../../interfaces/hub/core/IVoteManager.sol';
import { VoteManagerStorageV1 } from './VoteManagerStorageV1.sol';

contract VoteManager is IVoteManager, VoteManagerStorageV1 {
  function delegationManager(address account) external view override returns (address delegationManager_) {
    return _getVoteManagerStorageV1().delegationManagers[account];
  }

  function defaultDelegatee(address account) external view override returns (address defaultDelegatee_) {
    return _getVoteManagerStorageV1().defaultDelegatees[account];
  }

  function setDelegationManager(address delegationManager_) external override {
    _getVoteManagerStorageV1().delegationManagers[msg.sender] = delegationManager_;
    emit DelegationManagerSet(msg.sender, delegationManager_);
  }

  function setDefaultDelegatee(address defaultDelegatee_) external override {
    _getVoteManagerStorageV1().defaultDelegatees[msg.sender] = defaultDelegatee_;
    emit DefaultDelegateeSet(msg.sender, defaultDelegatee_);
  }
}
