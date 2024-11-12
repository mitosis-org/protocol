// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IDelegationRegistry } from '../../interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../../lib/StdError.sol';
import { DelegationRegistryStorageV1 } from './DelegationRegistryStorageV1.sol';

/**
 * @title DelegationRegistry
 * @notice Manages delegation relationships between accounts.
 */
contract DelegationRegistry is IDelegationRegistry, DelegationRegistryStorageV1, ContextUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address mitosis_) external initializer {
    StorageV1 storage $ = _getStorageV1();

    $.mitosis = mitosis_;
  }

  /**
   * @inheritdoc IDelegationRegistry
   */
  function mitosis() external view returns (address) {
    return _getStorageV1().mitosis;
  }

  /**
   * @inheritdoc IDelegationRegistry
   */
  function delegationManager(address account) external view returns (address) {
    return _delegationManager(_getStorageV1(), account);
  }

  /**
   * @inheritdoc IDelegationRegistry
   */
  function defaultDelegatee(address account) external view returns (address) {
    return _getStorageV1().defaultDelegatees[account];
  }

  /**
   * @inheritdoc IDelegationRegistry
   */
  function setDelegationManager(address account, address delegationManager_) external {
    StorageV1 storage $ = _getStorageV1();
    return _setDelegationManager($, _msgSender(), account, delegationManager_);
  }

  /**
   * @inheritdoc IDelegationRegistry
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external {
    StorageV1 storage $ = _getStorageV1();
    return _setDefaultDelegatee($, _msgSender(), account, defaultDelegatee_);
  }

  function setDelegationManagerByMitosis(address caller, address account, address delegationManager_) external {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == $.mitosis, StdError.Unauthorized());

    return _setDelegationManager($, caller, account, delegationManager_);
  }

  function setDefaultDelegateeByMitosis(address caller, address account, address defaultDelegatee_) external {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == $.mitosis, StdError.Unauthorized());

    return _setDefaultDelegatee($, caller, account, defaultDelegatee_);
  }

  //========================== NOTE: INTERNAL FUNCTIONS ==========================//

  function _delegationManager(StorageV1 storage $, address account) internal view returns (address) {
    address delegationManager_ = $.delegationManagers[account];
    return delegationManager_ == address(0) ? account : delegationManager_; // default to account
  }

  function _setDelegationManager(StorageV1 storage $, address caller, address account, address delegationManager_)
    internal
  {
    _assertSelfOrManager($, caller, account);

    $.delegationManagers[account] = delegationManager_;
    emit DelegationManagerSet(account, caller, delegationManager_);
  }

  function _setDefaultDelegatee(StorageV1 storage $, address caller, address account, address defaultDelegatee_)
    private
  {
    _assertSelfOrManager($, caller, account);

    $.defaultDelegatees[account] = defaultDelegatee_;
    emit DefaultDelegateeSet(account, caller, defaultDelegatee_);
  }

  function _assertSelfOrManager(StorageV1 storage $, address caller, address account) private view {
    require(caller == account || caller == _delegationManager($, account), StdError.Unauthorized());
  }
}
