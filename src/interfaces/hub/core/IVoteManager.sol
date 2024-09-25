// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IVoteManager {
  event DelegationManagerSet(address indexed account, address indexed delegationManager);
  event DefaultDelegateeSet(address indexed account, address indexed delegatee);

  function delegationManager(address account) external view returns (address delegationManager_);

  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);

  function setDelegationManager(address delegationManager_) external;

  function setDefaultDelegatee(address defaultDelegatee_) external;
}
