// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IDelegationRegistry {
  event DelegationManagerSet(address indexed account, address indexed delegationManager);
  event DefaultDelegateeSet(address indexed account, address indexed delegatee);
  event RedistributionRuleSet(address indexed account, address indexed redistributionRule);

  function delegationManager(address account) external view returns (address delegationManager_);

  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);

  function redistributionRule(address account) external view returns (address redistributionRule_);

  function setDelegationManager(address account, address delegationManager_) external;

  function setDefaultDelegatee(address account, address defaultDelegatee_) external;

  function setRedistributionRule(address account, address redistributionRule_) external;
}
