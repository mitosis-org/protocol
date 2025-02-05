// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IAssetManager } from '../interfaces/hub/core/IAssetManager.sol';
import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { IRedistributionRegistry } from '../interfaces/hub/core/IRedistributionRegistry.sol';
import { IReclaimQueue } from '../interfaces/hub/matrix/IReclaimQueue.sol';
import { IMitosis } from '../interfaces/hub/IMitosis.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

/**
 * @title Mitosis
 * @notice Main entry point for Mitosis contracts for third-party integrations.
 */
contract Mitosis is IMitosis, Ownable2StepUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.Mitosis
  struct MitosisStorage {
    IAssetManager assetManager;
    IReclaimQueue reclaimQueue;
    IDelegationRegistry delegationRegistry;
    IRedistributionRegistry redistributionRegistry;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.Mitosis';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getMitosisStorage() private view returns (MitosisStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // =========================== NOTE: INITIALIZERS  =========================== //

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  //====================== NOTE: CONTRACTS ======================//

  /**
   * @inheritdoc IMitosis
   */
  function reclaimQueue() external view returns (IReclaimQueue) {
    return _getMitosisStorage().reclaimQueue;
  }

  /**
   * @inheritdoc IMitosis
   */
  function assetManager() external view returns (IAssetManager) {
    return _getMitosisStorage().assetManager;
  }

  /**
   * @inheritdoc IMitosis
   */
  function delegationRegistry() external view returns (IDelegationRegistry) {
    return _getMitosisStorage().delegationRegistry;
  }

  /**
   * @inheritdoc IMitosis
   */
  function redistributionRegistry() external view returns (IRedistributionRegistry) {
    return _getMitosisStorage().redistributionRegistry;
  }

  //====================== NOTE: DELEGATION ======================//

  /**
   * @inheritdoc IMitosis
   */
  function delegationManager(address account) external view returns (address) {
    return _getMitosisStorage().delegationRegistry.delegationManager(account);
  }

  /**
   * @inheritdoc IMitosis
   */
  function defaultDelegatee(address account) external view returns (address) {
    return _getMitosisStorage().delegationRegistry.defaultDelegatee(account);
  }

  /**
   * @inheritdoc IMitosis
   */
  function setDelegationManager(address account, address delegationManager_) external {
    _getMitosisStorage().delegationRegistry.setDelegationManagerByMitosis(_msgSender(), account, delegationManager_);
  }

  /**
   * @inheritdoc IMitosis
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external {
    _getMitosisStorage().delegationRegistry.setDefaultDelegateeByMitosis(_msgSender(), account, defaultDelegatee_);
  }

  //====================== NOTE: REDISTRIBUTION ======================//

  /**
   * @inheritdoc IMitosis
   */
  function isRedistributionEnabled(address account) external view returns (bool) {
    return _getMitosisStorage().redistributionRegistry.isRedistributionEnabled(account);
  }

  /**
   * @inheritdoc IMitosis
   */
  function enableRedistribution() external {
    _getMitosisStorage().redistributionRegistry.enableRedistributionByMitosis(_msgSender());
  }

  // =========================== NOTE: State Setter  =========================== //

  function setAssetManager(IAssetManager assetManager_) external onlyOwner {
    MitosisStorage storage $ = _getMitosisStorage();
    $.assetManager = assetManager_;
    $.reclaimQueue = IReclaimQueue(assetManager_.reclaimQueue());
  }

  function setDelegationRegistry(IDelegationRegistry delegationRegistry_) external onlyOwner {
    _getMitosisStorage().delegationRegistry = delegationRegistry_;
  }

  function setRedistributionRegistry(IRedistributionRegistry redistributionRegistry_) external onlyOwner {
    _getMitosisStorage().redistributionRegistry = redistributionRegistry_;
  }
}
