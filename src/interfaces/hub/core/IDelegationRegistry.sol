// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IDelegationRegistry
 * @dev Common interface for {DelegationRegistry}.
 */
interface IDelegationRegistry {
  /**
   * @dev Emitted when the delegation manager is set for an account.
   * @param account The account that nominated the delegation manager
   * @param manager The delegation manager who tries to set the next delegation manager
   * @param delegationManager The delegation manager set
   */
  event DelegationManagerSet(address indexed account, address indexed manager, address indexed delegationManager);

  /**
   * @dev Emitted when the default delegatee is set for an account.
   * @param account The account that nominated the default delegatee
   * @param manager The delegation manager who tries to set the default delegatee
   * @param delegatee The default delegatee set
   */
  event DefaultDelegateeSet(address indexed account, address indexed manager, address indexed delegatee);

  /**
   * @dev Emitted when the redistribution rule is set for an account.
   * @param account The account that nominated the redistribution rule
   * @param manager The delegation manager who tries to set the redistribution rule
   * @param redistributionRule The redistribution rule set
   */
  event RedistributionRuleSet(address indexed account, address indexed manager, address indexed redistributionRule);

  /**
   * @dev Queries the delegation manager for `account`
   * @param account The account to query
   * @return delegationManager_ The delegation manager for `account`
   */
  function delegationManager(address account) external view returns (address delegationManager_);

  /**
   * @dev Queries the default delegatee for `account`
   * @param account The account to query
   * @return defaultDelegatee_ The default delegatee for `account`
   */
  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);

  /**
   * @dev Sets the delegation manager for `account`. Must emit the {DelegationManagerSet} event.
   * @dev If the `caller` is not the manager of `account` or self, it reverts with {StdError.Unauthorized}.
   * @param account The account to set the delegation manager for
   * @param delegationManager_ The delegation manager to set
   */
  function setDelegationManager(address account, address delegationManager_) external;

  /**
   * @dev Sets the default delegatee for `account`. Must emit the {DefaultDelegateeSet} event.
   * @dev If the `caller` is not the manager of `account` or self, it reverts with {StdError.Unauthorized}.
   * @param account The account to set the default delegatee for
   * @param defaultDelegatee_ The default delegatee to set
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external;
}
