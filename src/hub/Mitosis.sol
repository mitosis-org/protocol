// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IAssetManager } from '../interfaces/hub/core/IAssetManager.sol';
import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { IOptOutQueue } from '../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLGaugeGovernor } from '../interfaces/hub/eol/governance/IEOLGaugeGovernor.sol';
import { IEOLProtocolGovernor } from '../interfaces/hub/eol/governance/IEOLProtocolGovernor.sol';
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
    IOptOutQueue optOutQueue;
    IDelegationRegistry delegationRegistry;
    IEOLProtocolGovernor eolProtocolGovernor;
    IEOLGaugeGovernor eolGaugeGovernor;
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

  // =========================== NOTE: IMitosis  =========================== //

  /**
   * @inheritdoc IMitosis
   */
  function optOutQueue() external view returns (IOptOutQueue) {
    return _getMitosisStorage().optOutQueue;
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
  function eolProtocolGovernor() external view returns (IEOLProtocolGovernor) {
    return _getMitosisStorage().eolProtocolGovernor;
  }

  /**
   * @inheritdoc IMitosis
   */
  function eolGaugeGovernor() external view returns (IEOLGaugeGovernor) {
    return _getMitosisStorage().eolGaugeGovernor;
  }

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
    _getMitosisStorage().delegationRegistry.setDelegationManager(account, delegationManager_);
  }

  /**
   * @inheritdoc IMitosis
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external {
    _getMitosisStorage().delegationRegistry.setDefaultDelegatee(account, defaultDelegatee_);
  }

  // =========================== NOTE: State Setter  =========================== //

  function setAssetManager(IAssetManager assetManager_) external onlyOwner {
    MitosisStorage storage $ = _getMitosisStorage();
    $.assetManager = assetManager_;
    $.optOutQueue = IOptOutQueue(assetManager_.optOutQueue());
  }

  function setDelegationRegistry(IDelegationRegistry delegationRegistry_) external onlyOwner {
    _getMitosisStorage().delegationRegistry = delegationRegistry_;
  }

  function setEOLProtocolGovernor(IEOLProtocolGovernor eolProtocolGovernor_) external onlyOwner {
    _getMitosisStorage().eolProtocolGovernor = eolProtocolGovernor_;
  }

  function setEOLGaugeGovernor(IEOLGaugeGovernor eolGaugeGovernor_) external onlyOwner {
    _getMitosisStorage().eolGaugeGovernor = eolGaugeGovernor_;
  }
}
